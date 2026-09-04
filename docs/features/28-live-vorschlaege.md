# 28 Live-Vorschläge beim Anlegen

> **Status:** 🟢 fertig — Bier und Gasthaus, lokal sofort + Server nachladend.
> **Seit:** 0.10.3 · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Der Zweck ist **nicht** Tipparbeit zu sparen. Er ist Duplikatvermeidung.

Zwei Einträge für dasselbe Bier trennen Bewertungen, Abzeichen und
Statistik — dauerhaft und rückwirkend. Und niemand merkt es im Moment
des Anlegens: Wer ein Bier einträgt, hat die Datenbank ja gerade
vergeblich befragt (unbekannte EAN) und schließt daraus, dass es fehlt.
Der Schluss ist meistens falsch. Eine EAN bezeichnet die
**Handelseinheit**, nicht das Getränk; dieselbe Marke in 0,33 und 0,5
trägt zwei verschiedene Nummern. Der häufigste Grund für eine unbekannte
EAN ist deshalb nicht „neues Bier", sondern „bekanntes Bier ohne diesen
Barcode".

Der vorhandene Eintrag muss also auftauchen, **bevor** jemand den Namen
zu Ende getippt hat — nicht als Warnung hinterher.

## Funktion (Nutzersicht)

Ab dem zweiten Buchstaben im Feld „Marke" erscheinen passende Biere
direkt unter der Eingabezeile, zum Antippen. Wer `Baumg` tippt, sieht
„Baumgartner Märzen" und „Baumgartner Pils" mit Brauerei und Sorte.

Ein Tipp auf einen Vorschlag legt **kein zweites Bier an**:

| Lage | Was passiert |
|---|---|
| mit gescannter EAN | Der Barcode wird beim vorhandenen Bier nachgetragen (samt Gebindegröße), auch für alle anderen Nutzer. Fertig. |
| ohne EAN | Die Felder werden gefüllt, der Mensch arbeitet von dort weiter. |

Beim Gasthaus dasselbe: Die Liste ähnlicher Häuser gab es schon, war
aber **toter Text**. Sie sagte „gibt es das schon?" und ließ den
Menschen das vorhandene Haus trotzdem selbst suchen — wer gerade beim
Anlegen ist, macht dann meistens einfach fertig. Das Duplikat wurde
angekündigt statt verhindert. Jetzt führt ein Tipp direkt ins Bearbeiten
des vorhandenen Eintrags.

## Technische Umsetzung

- **Dateien:** `widgets/suggest_list.dart` (geteilte Darstellung),
  `features/beers/add_beer_screen.dart`,
  `features/venues/venue_edit_screen.dart`
- **Lokal zuerst:** `beersProvider` bzw. `venueSearchProvider` — beides
  Drift-Streams, also ohne Wartezeit und ohne Netz.
- **Server danach:** `OnlineService.searchCommunityBeers` holt
  nutzererstellte Biere anderer nach. Was lokal schon dasteht, wird
  nicht doppelt angeboten (Abgleich über den Namen, kleingeschrieben);
  Server-Treffer sind mit einem Wolkensymbol markiert.
- **Übernahme vom Server:** Das Bier liegt noch nicht lokal. Es wird über
  `actionsProvider.addBeer(…, barcode: ean)` eingetragen — **derselbe
  Weg, den der Scanner bei einem Community-Treffer geht**. Ein zweiter,
  eigener Importpfad hätte sich früher oder später anders verhalten als
  der erste.
- Lupe und Vorschlagsliste enden beide in `_uebernehmen()`, damit sie
  nicht auseinanderlaufen.

**Drei Fallen, die die Umsetzung bestimmt haben:**

1. **Entprellung nur für den Server.** Der lokale Teil hängt am
   Widget-Neuzeichnen und ist gratis. Die Serverabfrage wartet 300 ms.
   Ohne das schickte jeder Buchstabe eine Anfrage los — und die
   Antworten kämen in beliebiger Reihenfolge zurück.
2. **Alte Treffer sind schlimmer als keine.** Beim Tippen werden die
   Server-Treffer sofort geleert. Sie stehen zu lassen hieße, Treffer
   für ein altes Wort als Treffer für das anzuzeigen, was gerade
   dasteht. Zusätzlich wird jede Antwort verworfen, deren Suchwort nicht
   mehr im Feld steht.
3. **Nach der Übernahme ruht die Liste.** Sonst klappte sie sofort
   wieder auf — das Feld enthält jetzt ja exakt den gewählten Namen.

**Eingabe wird entschärft:** `%`, Komma, Klammern und Backslash werden
aus dem Suchbegriff entfernt, bevor er in ein `ilike`-Muster geht. Sonst
ließe sich das LIKE-Muster bzw. die PostgREST-Filtersyntax kapern.

**Ohne Verbindung ändert sich nichts.** Die Serversuche gibt bei jedem
Fehler eine leere Liste zurück, die lokalen Vorschläge bleiben. Wer
offline ein Bier anlegt, soll von der Funktion nichts merken.

## Modularität

- **Hängt ab von:** Bier- und Brauerei-Datenbank (04), Gasthäuser (05)
- **Wird gebraucht von:** nichts — rein additiv
- **Ausbauen:** `suggest_list.dart` löschen und die zwei Aufrufstellen
  entfernen. Die Formulare funktionieren unverändert weiter.

`SuggestList` liegt in `widgets/`, weil Bier- und Gasthaus-Formular sie
beide brauchen und Features einander nicht importieren dürfen.

## Plattformen

Alle. Keine plattformspezifische Technik.

## Skalierung

Die lokale Suche läuft gegen die gebündelte Datenbank (660 Biere) —
unkritisch. Die Serversuche nutzt `ilike '%begriff%'` auf `beers.name`
und ist auf 10 Treffer begrenzt. Ein `pg_trgm`-Index fehlt dort noch;
bei wenigen tausend Bieren ist das unmessbar, aber es ist derselbe
Befund wie seinerzeit bei der Freundessuche (0027) und wird dieselbe
Lösung brauchen.

## Umsetzungsstatus

Vollständig für Bier und Gasthaus. Sieben Widget-Tests
(`test/live_vorschlaege_test.dart`), darunter der entscheidende: Nach
dem Antippen eines Vorschlags stehen **zwei** Biere in der Datenbank,
nicht drei.

## Umsetzungsplan

1. ~~Bier-Formular~~ — erledigt
2. ~~Gasthaus-Formular anklickbar~~ — erledigt
3. Trigram-Index auf `beers.name`, sobald die Serversuche spürbar wird

## Offene Punkte / Ideen

- Vorschläge auch im Brauerei-Feld — dort entstehen Duplikate wie
  „Brauerei Baumgartner" / „Baumgartner" leicht
- Tastaturbedienung (Pfeiltasten) für die Web-App
