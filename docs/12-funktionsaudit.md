# 12 — Funktionsaudit

> **Erstellt:** 2026-08-15 (0.9.13-beta) ·
> **Nachgeführt:** 2026-09-06 (0.10.27-beta)

Durchsicht aller bestehenden Funktionen auf drei Fragen: Ist sie
vollständig? Ist sie sinnvoll geschnitten? Trägt sie Wachstum?

Der Befund war schon 2026-08-15 gut — die App ist funktional weiter, als
der Beta-Stand vermuten lässt. Die Schwächen lagen fast alle an derselben
Stelle: Sie stammten aus der Zeit, als „viele Daten" fünf Check-ins hieß.

**Von den ursprünglichen Befunden ist keiner mehr offen.** Sie sind
erledigt und hier durchgestrichen statt gelöscht — ein Audit, das seine
eigene Geschichte verschweigt, sieht aus, als hätte es nie Mängel gegeben.
Durchgestrichenes ist **nicht mehr zu tun.**

Am 2026-09-06 stand die Zusammenfassung unten noch auf fünf offenen
Zeilen, während der Fließtext darunter vier davon längst als erledigt
beschrieb. **Eine Tabelle, die dem eigenen Text widerspricht, ist die
gefährlichere Hälfte** — sie wird zuerst gelesen und zuletzt gepflegt.

## Zusammenfassung

| Befund | Schwere | Betrifft |
|---|---|---|
| ~~Listen konstruieren alle Einträge je Rebuild~~ | erledigt | Feed, Tagebuch, Biere, Gasthäuser, Bestenliste |
| ~~Feed-Abfrage ohne Obergrenze (lokal)~~ | erledigt | Feed |
| ~~Eigene Check-ins nicht löschbar~~ | erledigt | Feed, Tagebuch |
| ~~Fehlender Index auf `checkins.created_at`~~ | erledigt (0020) | Feed |
| ~~Freundessuche über `display_name` ohne Trigram-Index~~ | erledigt (0027) | Freundessuche |
| ~~Statistiken bleiben unter ihren Möglichkeiten~~ | erledigt (0.9.15, Ausbau bis 0.10.27) | Profil |
| ~~Cloud-Wiederherstellung holt immer alles~~ | erledigt (Backlog B-2) | Synchronisation |
| ~~Beacon-Laufzeit nicht wählbar~~ | erledigt (0021) | Sessions |
| ~~Freunde ohne Abstufung~~ | erledigt (0024) | Freunde, Sichtbarkeit |
| Community-DB wird als Ganzes geladen | niedrig, bewusst | Bierdatenbank |

## Die Listen sind das dringendste Problem

Zwei Befunde, die zusammengehören — der zweite ist der schwerere.

**Erstens: unbegrenzte Abfragen.** `watchFeed()` hatte gar keine
Obergrenze: Es las *alle* Check-ins aus SQLite, verband sie mit Bier,
Brauerei und Profil und legte für jeden ein `CheckinDetails`-Objekt an.
Das ist echte, eifrige Arbeit — sie fällt bei jedem Datenbank-Ereignis neu
an und wächst linear mit dem Bestand. Die Serverseite war mit 50 gedeckelt,
aber ohne „mehr laden": Wer länger weg war, sah den Rest nie.

**Zweitens: eifrig konstruierte Listen.** In den Bildschirmen standen
**26** `ListView(children: […])` gegen **eine** `ListView.builder`.

Hier ist Genauigkeit wichtig, weil die naheliegende Formulierung falsch
wäre: Flutter erzeugt die Elemente und Render-Objekte auch bei
`children:` nur für den sichtbaren Ausschnitt. Was tatsächlich eifrig
passiert, ist das **Konstruieren der Widget-Beschreibungen** — bei jedem
Rebuild, für jeden Eintrag. Bei der Bierliste hieß das damals 280 Objekte
pro Tastendruck im Suchfeld — heute wären es 660. Spürbar wird das früher als die Element-Inflation,
aber es ist kein Einfrieren, sondern zunehmende Zähigkeit.

Für Formulare ist `children:` richtig und harmlos — ein
Bearbeiten-Bildschirm hat zwölf Felder, fertig. Falsch ist es für alles,
was mit der Nutzung **wächst**:

- `feed_screen.dart` — jeder Check-in aller Freunde
- `diary_screen.dart` — das eigene Tagebuch, wächst ein Leben lang
- `beers_screen.dart` — damals 280 Biere, heute 660, neu bei jedem
  Tastendruck
- `venues_list_screen.dart` — alle Gasthäuser
- `leaderboard_screen.dart` — alle Beitragenden

**Erledigt seit 0.9.14:** `watchFeed` nimmt eine Obergrenze; Feed und
Tagebuch laden 30er-Seiten und wachsen beim Scrollen. Feed, Tagebuch,
Bierliste, Gasthausliste und Bestenliste bauen faul. Die Suche im
Tagebuch wanderte dabei in die Abfrage — ein Filter über das geladene
Fenster hätte sonst nur noch die letzten Seiten durchsucht, und das wäre
eine schlechtere Suche als vorher gewesen.

Die verbleibenden `children:`-Listen sind Formulare und
Detailbildschirme mit fester Anzahl Zeilen. Dort ist die eifrige Variante
richtig und bleibt.

## Fehlende Datenbank-Indizes

Der Freundes-Feed fragt `profile_id <> ich` und sortiert nach
`created_at desc`. Auf `checkins` liegt seit 0001 ein zusammengesetzter
Index `(profile_id, created_at desc)` — der bedient das eigene Tagebuch
perfekt, dem Feed hilft er aber nicht: Die führende Spalte ist hier nicht
per Gleichheit eingeschränkt, also fällt Postgres auf einen vollen
Durchlauf mit anschließendem Sortieren zurück.

Was fehlte, war ein eigener Index auf `(created_at desc)` — nachgeliefert
in **Migration 0020**. Solange die Tabelle klein ist, merkt das niemand;
ab einigen zehntausend Zeilen wird das Sortieren teuer.

Die Freundessuche durchsucht auch den Anzeigenamen und benutzt
`ilike '%begriff%'`. Ein solcher Ausdruck kann einen normalen Index
prinzipiell nicht nutzen — er braucht `pg_trgm` mit einem GIN-Index.
**Nachgeliefert in Migration 0027**; live liegen zwei GIN-Indizes
(nachgeprüft am 2026-09-04 über `pg_indexes`).

## Was funktional fehlt

**~~Check-ins lassen sich nicht löschen.~~** War die klarste Lücke im
Bestand: Wer sich vertippte oder das falsche Bier scannte, hatte keine
Handhabe außer der Löschung des ganzen Kontos. Seit 0.9.14 erledigt
([Funktion 19](features/19-feed-eintraege-loeschen.md)); das
**Bearbeiten** kam mit 0.10.x dazu
([Funktion 27](features/27-check-ins-bearbeiten.md)).

**~~Die Statistiken bleiben unter ihren Möglichkeiten.~~** Der Befund
stammt vom 2026-08-15 und war **schon vier Wochen später überholt**: Seit
0.9.15 gibt es einen eigenen Statistikbereich mit Mengen, vier
Aufteilungen, Zeitraum, Filtern und Monatsverlauf
([Funktion 20](features/20-feed-statistiken.md), 15 Tests). Auch die
Füllmenge je Check-in, die hier als Hauptlücke stand, gibt es seit
0022/Drift v11.

⚠️ **Das ist die Stelle, an der dieses Dokument selbst zum Fehler wurde.**
Am 2026-09-04 habe ich anhand dieses Absatzes berichtet, die Statistik
sei die größte offene Lücke — sie war längst gebaut. Ein Audit, das nicht
nachgeführt wird, ist keine Bestandsaufnahme mehr, sondern eine
Behauptung. Dieselbe Lehre wie in
[docs/13, Lehre 1](13-migrationen-und-lehren.md), nur eine Ebene höher:
**Vor dem Berichten gegen die Wirklichkeit prüfen, nicht gegen die
Notiz.**

**Auch die Ausbaustufe 2 ist inzwischen zum größten Teil gebaut:** acht
Aufteilungen, neun Kennzahlen, konfigurierbare Kacheln
([Funktion 20](features/20-feed-statistiken.md)), CSV-Export
([#133](https://github.com/ORPA1988/BrewMates/issues/133)), anonymer
Vergleich mit allen anderen ([Funktion 42](features/42-vergleich-mit-anderen.md)),
Wochen-Heatmap ([Funktion 45](features/45-wochen-heatmap.md)) und
Jahresrückblick ([Funktion 46](features/46-jahresrueckblick.md)). Offen
bleibt der Vergleich zum **Vorzeitraum**.

**~~Beacons laufen fest.~~** Die Laufzeit war einprogrammiert. Seit
0.9.14 wählbar, verlängerbar und serverseitig auf 29 min–24 h begrenzt
(0021, [Funktion 23](features/23-beacon-laufzeit.md)). Seit 0.10.13 kann
man auf einen fremden Beacon außerdem **zu- und absagen**
([Funktion 07](features/07-sessions-und-beacons.md)).

**~~Freunde sind eine flache Menge.~~** Entweder jemand sah alles, oder
er war kein Freund. Seit 0024 gibt es **Freundeskreise** (Bekannter /
Freund / Enger Freund) mit serverseitiger Durchsetzung
([Funktion 24](features/24-freundeskreise.md)).

**Damit ist von den ursprünglichen Befunden keiner mehr offen.** Der
Bestand trägt; was jetzt lohnt, ist nicht mehr Nachrüsten, sondern
Gestaltung — Abzeichen, Challenges und die Oberfläche, die beides zeigt.

## Was gut ist und so bleiben sollte

Damit das Audit nicht nur Mängel aufzählt — diese Entscheidungen tragen:

- **Local-first.** Check-in, Tagebuch und Bierdatenbank funktionieren ohne
  Netz. Das ist der Grund, warum die App im Bierkeller nicht ausfällt.
- **Die Feature-Ordner sind sauber getrennt.** Kein Bildschirm importiert
  einen anderen. Eine Funktion zu entfernen ist deshalb wirklich möglich.
- **Serverseitige Durchsetzung.** Challenges werden per RPC validiert,
  Blockieren und Sichtbarkeit hängen an RLS-Regeln statt an der Oberfläche.
  Wer die App umgeht, kommt trotzdem nicht weiter.
- **Die Offline-Warteschlange für Gasthäuser** (`venue_edit_queue`) ist das
  richtige Muster für schreibende Aktionen: sofort lokal, Abgleich später.
  Sie sollte die Vorlage für Check-in-Löschungen und weitere Schreibpfade
  sein.
- **Nichts hängt mehr an fremden CDNs.** Schriften, Engine, Datenbank-WASM
  und Scanner-Bibliothek liegen im eigenen Bundle.

## Skalierung: wo es kippt

Grobe Einschätzung, ab wann welcher Punkt weh tut:

| Größe | Was passiert |
|---|---|
| **~50 Nutzer** | Nichts. Der heutige Stand trägt das mühelos. |
| **~500 Nutzer / 10.000 Check-ins** | ~~Tagebuch und Feed werden träge~~ — entschärft durch Seitenladen und Index 0020. |
| **~5.000 Nutzer** | ~~Freundessuche ohne Trigram-Index~~ (0027) und ~~Cloud-Wiederherstellung, die immer alles holt~~ (inkrementell seit Backlog B-2) — beide entschärft. |
| **~50.000 Nutzer** | Die Community-Datenbank als acht Volldateien im Bundle ist nicht mehr sinnvoll; es braucht serverseitige Suche statt lokaler Vollkopie. |

Die zweite und die dritte Stufe sind erledigt. Die letzte wäre ein Umbau,
der jetzt weder nötig noch klug wäre.

## Empfohlene Reihenfolge

1. ~~Check-ins löschbar machen~~ — erledigt (0.9.14)
2. ~~Listen auf faules Bauen umstellen + Feed seitenweise laden~~ —
   erledigt (0.9.14)
3. ~~Index für den Feed~~ — erledigt (Migration 0020)
4. ~~Füllmenge erfassen, dann die Statistiken darauf aufbauen~~ —
   erledigt (0022/Drift v11, Gebinde am Barcode seit 0.10.17)
5. Alles Weitere nach Roadmap
