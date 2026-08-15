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
| Listen bauen alle Einträge sofort | **hoch** | Feed, Tagebuch, Biere, Gasthäuser, Bestenliste |
| Feed-Abfrage ohne Obergrenze (lokal) | **hoch** | Feed |
| Eigene Check-ins nicht löschbar | **hoch** | Feed, Tagebuch |
| Fehlender Index auf `checkins.created_at` | mittel | Feed |
| Freundessuche über `display_name` ohne Trigram-Index | mittel | Freundessuche |
| Statistiken bleiben unter ihren Möglichkeiten | mittel | Profil |
| Cloud-Wiederherstellung holt immer alles | mittel | Synchronisation |
| Beacon-Laufzeit nicht wählbar | niedrig | Sessions |
| Freunde ohne Abstufung | niedrig | Freunde, Sichtbarkeit |
| Community-DB wird als Ganzes geladen | niedrig | Bierdatenbank |

## Die Listen sind das dringendste Problem

In den Bildschirmen stehen **26 eifrige Listen** (`ListView(children: […])`)
und **eine einzige faule** (`ListView.builder`). Eine eifrige Liste baut
jeden Eintrag sofort — auch die 800, die niemand sieht.

Für Formulare ist das richtig und harmlos: Ein Bearbeiten-Bildschirm hat
zwölf Felder, fertig. Für alles, was mit der Nutzung **wächst**, ist es
falsch:

- `feed_screen.dart` — jeder Check-in aller Freunde
- `diary_screen.dart` — das eigene Tagebuch, wächst ein Leben lang
- `beers_screen.dart` — 280 Biere heute, mehr morgen
- `venues_list_screen.dart` — alle Gasthäuser
- `leaderboard_screen.dart` — alle Beitragenden

Bei den heutigen Datenmengen merkt das niemand. Bei tausend Check-ins wird
das Öffnen des Tagebuchs zur Gedenkminute. Die Umstellung ist mechanisch
(`ListView.builder` mit `itemCount`) und sollte passieren, bevor jemand
genug Daten hat, um es zu spüren.

**Verschärfend beim Feed:** Die lokale Abfrage `watchFeed()` hat gar keine
Obergrenze — sie liest alle Check-ins, sortiert sie und gibt sie
vollständig zurück. Die Serverseite ist mit 50 gedeckelt, aber ohne
„mehr laden": Wer länger weg war, sieht den Rest nie. Beides gehört
zusammen gelöst — Seitenweise nachladen statt alles auf einmal.

## Fehlende Datenbank-Indizes

Der Feed sortiert nach `created_at` absteigend, aber auf `checkins` gibt es
nur Indizes für `profile_id`, `beer_id` und `session_id`. Solange die
Tabelle klein ist, sortiert Postgres eben durch; ab einigen zehntausend
Zeilen wird das teuer. Richtig wäre ein zusammengesetzter Index
`(profile_id, created_at desc)`, der beides bedient.

Die Freundessuche, die seit heute auch den Anzeigenamen durchsucht,
benutzt `ilike '%begriff%'`. Ein solcher Ausdruck kann einen normalen
Index prinzipiell nicht nutzen — er braucht `pg_trgm` mit einem
GIN-Index. Bei zwei Profilen ist das egal, bei zehntausend nicht mehr.
Kein Fehler, aber eine Schuld, die man kennen muss.

## Was funktional fehlt

**Check-ins lassen sich nicht löschen.** Weder im Feed noch im Tagebuch.
Wer sich vertippt, das falsche Bier scannt oder einen Abend nicht
dokumentiert haben möchte, hat keine Handhabe außer der Löschung des
ganzen Kontos. Das ist die klarste Lücke im Bestand — und der Grund, warum
sie als [Funktion 19](features/19-feed-eintraege-loeschen.md) als erstes
dran ist.

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
| **~500 Nutzer / 10.000 Check-ins** | Tagebuch und Feed werden spürbar träge (eifrige Listen). Der fehlende `created_at`-Index macht sich bemerkbar. |
| **~5.000 Nutzer** | Die Freundessuche ohne Trigram-Index wird langsam. Die Cloud-Wiederherstellung, die immer alles holt, wird beim Gerätewechsel unangenehm. |
| **~50.000 Nutzer** | Die Community-Datenbank als acht Volldateien im Bundle ist nicht mehr sinnvoll; es braucht serverseitige Suche statt lokaler Vollkopie. |

Die ersten beiden Stufen sind mit überschaubarem Aufwand zu entschärfen
und sollten vor dem Play-Store-Start erledigt sein. Die letzte ist ein
Umbau, der jetzt weder nötig noch klug wäre.

## Empfohlene Reihenfolge

1. **Check-ins löschbar machen** — echte Nutzerlücke, klein umzusetzen
2. **Listen auf faules Bauen umstellen** + Feed seitenweise laden —
   mechanisch, verhindert das absehbare Trägewerden
3. **Index auf `checkins(profile_id, created_at desc)`** — eine Migration
4. **Gebinde erfassen**, dann die Statistiken darauf aufbauen
5. Alles Weitere nach Roadmap
