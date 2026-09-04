# 21 Hintergrundgeschichten

> **Status:** 🟡 teilweise — Feld, Anzeige und Erst-Scan-Hinweis stehen;
> 34 von 137 Brauereien haben bislang eine Geschichte.
> **Seit:** 0.9.16-beta · **Zuletzt geprüft:** 2026-09-02

## Zielsetzung

Ein Bier ist selten nur ein Getränk. Hinter den meisten Brauereien im
DACH-Raum stehen Jahrhunderte, Familienstreits, Klöster, Kriege,
Beinahe-Pleiten und stures Festhalten an einem Rezept. Wer beim Scannen
erfährt, dass sein Feierabendbier von einer Brauerei stammt, die seit 1040
braut, trinkt dasselbe Bier anders.

Genau das unterscheidet BrewMates von einer Zähl-App: nicht mehr Zahlen,
sondern mehr **Bedeutung**. Und es ist der Unterbau für alles Spätere —
verifizierte Brauereiinhaber und Angebote setzen voraus, dass es zu jeder
Brauerei überhaupt einen gepflegten Eintrag gibt.

## Funktion (Nutzersicht)

**Beim ersten Mal, nie wieder ungefragt.** Scannt jemand ein Bier, das er
noch nie eingecheckt hat, und es gibt eine Geschichte dazu, erscheint auf
der Treffer-Bestätigung ein kleiner Hinweis: „📖 Wusstest du…?". Ein Tippen
öffnet die Geschichte, Wegwischen übergeht sie. Beim zweiten Scan
desselben Biers erscheint der Hinweis nicht mehr — nachlesen lässt sich
die Geschichte jederzeit auf der Bier- bzw. Brauereiseite.

Der Ton ist der eines Menschen, der etwas erzählt: zwei bis fünf Sätze,
eine gute Anekdote, kein Werbetext und kein Wikipedia-Auszug.

**Bei Brauereien** steht die Geschichte fest im Detailbereich. Das Ziel
ist, dass jede Brauerei Hintergrund bekommt, nicht nur die berühmten —
erreicht ist das noch nicht (Stand 2026-09-04: 34 von 137).

**Bearbeiten** dürfen Vertrauensstufe 3 und höher (Bierkenner, Moderator,
Admin), wie bei den übrigen Community-Daten. Änderungen laufen über das
bestehende Änderungsprotokoll.

## Technische Umsetzung

- **Daten:** neues Feld `story` (Text) bei Bier und Brauerei — in den
  JSON-Dateien, in Supabase (Migration 0023) und in Drift (v12)
- **Geändert:** `data/community_sync.dart` (Feld mitlesen),
  `features/beers/beer_detail_screen.dart`,
  `features/beers/brewery_detail_screen.dart`,
  `features/scan/scan_screen.dart` (Hinweis auf der Bestätigung)
- **Neu:** `features/beers/story_sheet.dart` — `StorySection` für die
  Detailseiten, `showStorySheet` für den Hinweis beim Scan

**Serverseitig war nichts an den Rechten zu tun:** Die bestehenden
`update`-Policies auf `beers` und `breweries` gelten für die ganze Zeile
und decken die neue Spalte mit ab — Vertrauensstufe 3 darf sie also
bearbeiten, und jede Änderung landet wie gehabt im `edit_log`. Migration
0023 setzt zusätzlich eine Längengrenze von 1200 Zeichen: Sie hält die
Geschichten bei „Anekdote" statt „Aufsatz".

**Rückfall auf die Brauerei:** Hat ein Bier keine eigene Geschichte,
zeigt der Scanner die der Brauerei. Das ist der häufigere und oft
interessantere Fall — Brauereigeschichten skalieren besser als
Biergeschichten.

**„Schon gesehen?"** braucht keine neue Tabelle: Ein Bier gilt als bekannt,
sobald ein eigener Check-in darauf existiert. Der Hinweis erscheint also
genau beim ersten Mal, und das ohne zusätzlichen Zustand — der aufwendigere
Weg (eine Tabelle gesehener Geschichten) wäre nur nötig, wenn man auch
ohne Check-in markieren wollte.

**Herkunft und Sorgfalt.** Es gilt dieselbe Regel wie bei den übrigen
Daten, hier aber besonders streng: **lieber kein Eintrag als ein
erfundener.** Eine plausibel klingende, aber falsche Brauereigeschichte
ist schlimmer als eine leere Fläche — sie wird geglaubt und
weitererzählt. Aufgenommen ist deshalb nur, was allgemein bekannt und gut
belegt ist; unsichere Superlative stehen als Anspruch da („gilt als",
„nach eigener Zählung") und nicht als Tatsache. Brauereien ohne
gesicherte Geschichte bekommen kein Feld, und die Anzeige lässt den
Abschnitt dann weg.

Rechtlich: eigene Formulierungen, keine übernommenen Texte von
Brauerei-Webseiten oder aus Wikipedia. Zahlen und Jahreszahlen dürfen aus
öffentlichen Quellen stammen, die Sätze sind unsere. Festgehalten in
`app/assets/data/DATENHERKUNFT.md`.

## Modularität

- **Hängt ab von:** Bier- & Brauerei-DB (04), Vertrauensstufen (15)
- **Wird gebraucht von:** Brauerei-Besitz (25) baut darauf auf
- **Ausbauen:** Anzeige-Datei löschen, Hinweis im Scanner entfernen, Feld
  in den JSONs stehen lassen (stört nicht) oder in einer Migration
  entfernen.

## Plattformen

Alle. Nur Text.

## Skalierung

Ein Textfeld je Bier und Brauerei erhöht die gebündelten JSON-Dateien
spürbar — bei 660 Bieren und 137 Brauereien und je 400 Zeichen wären das
rund 340 KB zusätzlich, wenn alle eine hätten. Vertretbar. Ab etwa dem Dreifachen sollten die
Geschichten aus den gebündelten Dateien heraus und bei Bedarf nachgeladen
werden; dann trägt der Bundle nur noch, was ohne Netz nötig ist.

## Umsetzungsstatus

Technik vollständig, Inhalte begonnen:

- Feld, Migration, Import, Anzeige und Erst-Scan-Hinweis stehen
- Bearbeiten ab Stufe 3 funktioniert ohne eigenes Zutun (bestehende
  Policies)
- **30 Brauereien** haben eine Geschichte (Österreich 13, Bayern 17),
  dazu ein Bier (Samichlaus)

Abgesichert durch `test/story_test.dart` (5 Tests): Import, Längengrenze,
kein leerer Text statt null, „erstes Mal" am fehlenden eigenen Check-in,
fremder Check-in macht ein Bier nicht bekannt.

## Umsetzungsplan

1. **Restliche Brauereien** — Deutschland (40) und Schweiz (18) haben noch
   keine Geschichte; dazu die 74 übrigen aus Österreich (58 von 71) und
   Bayern (16 von 33).
   Fortlaufend bei jedem Entwicklungslauf, im selben Zug wie die
   Datenpflege.
2. **Biergeschichten** für die Klassiker, wo es mehr zu erzählen gibt als
   über die Brauerei.

## Offene Punkte / Ideen

- Bilder zur Geschichte (historische Etiketten) — erst klären, unter
  welcher Lizenz
- Geschichten zu Gasthäusern, sobald genug gepflegte Einträge existieren
