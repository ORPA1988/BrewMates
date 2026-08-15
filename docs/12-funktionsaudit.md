# Funktionsaudit

**Stand: 2026-08-15, Version 0.9.13-beta.** Durchsicht aller bestehenden
Funktionen auf drei Fragen: Ist sie vollständig? Ist sie sinnvoll
geschnitten? Trägt sie Wachstum?

Der Befund ist insgesamt gut — die App ist funktional weiter, als der
Beta-Stand vermuten lässt. Die Schwächen liegen fast alle an derselben
Stelle: Sie stammen aus der Zeit, als „viele Daten" fünf Check-ins hieß.

## Zusammenfassung

| Befund | Schwere | Betrifft |
|---|---|---|
| ~~Listen konstruieren alle Einträge je Rebuild~~ | erledigt | Feed, Tagebuch, Biere, Gasthäuser, Bestenliste |
| ~~Feed-Abfrage ohne Obergrenze (lokal)~~ | erledigt | Feed |
| ~~Eigene Check-ins nicht löschbar~~ | erledigt | Feed, Tagebuch |
| ~~Fehlender Index auf `checkins.created_at`~~ | erledigt (0020) | Feed |
| Freundessuche über `display_name` ohne Trigram-Index | mittel | Freundessuche |
| Statistiken bleiben unter ihren Möglichkeiten | mittel | Profil |
| Cloud-Wiederherstellung holt immer alles | mittel | Synchronisation |
| Beacon-Laufzeit nicht wählbar | niedrig | Sessions |
| Freunde ohne Abstufung | niedrig | Freunde, Sichtbarkeit |
| Community-DB wird als Ganzes geladen | niedrig | Bierdatenbank |

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
Rebuild, für jeden Eintrag. Bei der Bierliste heißt das: 280 Objekte pro
Tastendruck im Suchfeld. Spürbar wird das früher als die Element-Inflation,
aber es ist kein Einfrieren, sondern zunehmende Zähigkeit.

Für Formulare ist `children:` richtig und harmlos — ein
Bearbeiten-Bildschirm hat zwölf Felder, fertig. Falsch ist es für alles,
was mit der Nutzung **wächst**:

- `feed_screen.dart` — jeder Check-in aller Freunde
- `diary_screen.dart` — das eigene Tagebuch, wächst ein Leben lang
- `beers_screen.dart` — 280 Biere heute, mehr morgen, neu bei jedem
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

Die Freundessuche, die seit heute auch den Anzeigenamen durchsucht,
benutzt `ilike '%begriff%'`. Ein solcher Ausdruck kann einen normalen
Index prinzipiell nicht nutzen — er braucht `pg_trgm` mit einem
GIN-Index. Bei zwei Profilen ist das egal, bei zehntausend nicht mehr.
Kein Fehler, aber eine Schuld, die man kennen muss.

## Was funktional fehlt

**~~Check-ins lassen sich nicht löschen.~~** War die klarste Lücke im
Bestand: Wer sich vertippte oder das falsche Bier scannte, hatte keine
Handhabe außer der Löschung des ganzen Kontos. Seit 0.9.14 erledigt,
siehe [Funktion 19](features/19-feed-eintraege-loeschen.md). Offen bleibt
das **Bearbeiten** — es deckt vermutlich die Hälfte der Löschwünsche ab.

**Die Statistiken bleiben unter ihren Möglichkeiten.** Das Profil zeigt
Zähler: Check-ins, Stile, Länder, Wochen-Serie. Fast alle Daten für echte
Auswertungen liegen längst da — Land, Stil, Alkoholgehalt, Zeitpunkt,
Gasthaus und sogar das Gebinde (`ServingStyle`: Fass, Flasche, Dose,
Growler). Was fehlt, ist die Auswertung selbst, ein Weg sie zu filtern —
und die **Menge**: Ohne Füllmenge je Check-in gibt es keine Literangabe,
und genau danach fragt man als erstes. Siehe
[Funktion 20](features/20-feed-statistiken.md).

**Beacons laufen fest.** Die Laufzeit ist einprogrammiert, nicht wählbar.
Wer zwei Stunden im Wirtshaus sitzt, hat dieselbe Anzeige wie jemand, der
kurz auf ein Feierabendbier vorbeischaut.

**Freunde sind eine flache Menge.** Entweder jemand sieht alles, oder er
ist kein Freund. Für ein Werkzeug, das Standort und Trinkverhalten zeigt,
ist das grob — Arbeitskollegen und beste Freunde verdienen unterschiedliche
Nähe.

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
| **~5.000 Nutzer** | Die Freundessuche ohne Trigram-Index wird langsam. Die Cloud-Wiederherstellung, die immer alles holt, wird beim Gerätewechsel unangenehm. |
| **~50.000 Nutzer** | Die Community-Datenbank als acht Volldateien im Bundle ist nicht mehr sinnvoll; es braucht serverseitige Suche statt lokaler Vollkopie. |

Die zweite Stufe ist erledigt. Die dritte ist mit überschaubarem Aufwand
zu entschärfen, die letzte wäre ein Umbau, der jetzt weder nötig noch
klug wäre.

## Empfohlene Reihenfolge

1. ~~Check-ins löschbar machen~~ — erledigt (0.9.14)
2. ~~Listen auf faules Bauen umstellen + Feed seitenweise laden~~ —
   erledigt (0.9.14)
3. ~~Index für den Feed~~ — erledigt (Migration 0020)
4. **Füllmenge erfassen**, dann die Statistiken darauf aufbauen
5. Alles Weitere nach Roadmap
