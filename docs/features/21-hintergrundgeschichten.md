# 21 Hintergrundgeschichten

> **Status:** 🔴 geplant — die Datenfelder für kurze Notizen existieren
> (`breweries.notes`, `beers.description_*`), Geschichten und ihre Anzeige
> nicht.
> **Geplant für:** 0.9.16-beta · **Zuletzt geprüft:** 2026-08-15

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
desselben Biers erscheint der Hinweis nicht mehr — er lässt sich in der
Bier-Ansicht jederzeit wieder aufrufen.

Der Ton ist der eines Menschen, der etwas erzählt: zwei bis fünf Sätze,
eine gute Anekdote, kein Werbetext und kein Wikipedia-Auszug.

**Bei Brauereien** steht die Geschichte fest im Detailbereich — jede
Brauerei bekommt Hintergrund, nicht nur die berühmten.

**Bearbeiten** dürfen Vertrauensstufe 3 und höher (Bierkenner, Moderator,
Admin), wie bei den übrigen Community-Daten. Änderungen laufen über das
bestehende Änderungsprotokoll.

## Technische Umsetzung

- **Daten:** neues Feld `story` (Text) bei Bier und Brauerei — in den acht
  JSON-Dateien, in Supabase (Migration) und in Drift (v12)
- **Geändert:** `data/community_sync.dart` (Feld mitlesen),
  `features/beers/beer_detail_screen.dart`,
  `features/beers/brewery_detail_screen.dart`,
  `features/scan/scan_screen.dart` (Hinweis auf der Bestätigung)
- **Neu:** `features/beers/story_sheet.dart` — die Anzeige

**„Schon gesehen?"** braucht keine neue Tabelle: Ein Bier gilt als bekannt,
sobald ein eigener Check-in darauf existiert. Der Hinweis erscheint also
genau beim ersten Mal, und das ohne zusätzlichen Zustand — der aufwendigere
Weg (eine Tabelle gesehener Geschichten) wäre nur nötig, wenn man auch
ohne Check-in markieren wollte.

**Herkunft und Sorgfalt.** Die Geschichten recherchiere ich; jede kommt mit
Quelle in die Pflegedoku, und es gilt dieselbe Regel wie bei den übrigen
Daten: **lieber kein Eintrag als ein erfundener.** Eine plausibel
klingende, aber falsche Brauereigeschichte ist schlimmer als eine leere
Fläche — sie wird geglaubt und weitererzählt. Unbelegtes bleibt weg.

Rechtlich: eigene Formulierungen, keine übernommenen Texte von
Brauerei-Webseiten. Zahlen und Jahreszahlen dürfen aus öffentlichen
Quellen stammen, die Sätze müssen unsere sein.

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
spürbar — bei 280 Bieren und 125 Brauereien und je 400 Zeichen sind das
rund 160 KB zusätzlich. Vertretbar. Ab etwa dem Dreifachen sollten die
Geschichten aus den gebündelten Dateien heraus und bei Bedarf nachgeladen
werden; dann trägt der Bundle nur noch, was ohne Netz nötig ist.

## Umsetzungsplan

1. **Feld überall ergänzen.** Migration (Supabase), Drift v12,
   `community_sync` liest `story`, JSON-Schema in der Pflegedoku
   nachziehen.
   *Prüfkriterium:* Import-Test — Geschichte landet in der lokalen DB.
2. **Anzeige.** `story_sheet.dart`, eingebunden in Bier- und
   Brauerei-Detail.
   *Prüfkriterium:* Widget-Test — ohne Geschichte erscheint kein leerer
   Bereich.
3. **Hinweis beim ersten Scan.** Bedingung: Geschichte vorhanden **und**
   kein eigener Check-in auf dieses Bier.
   *Prüfkriterium:* Test — beim zweiten Scan erscheint nichts.
4. **Bearbeiten ab Stufe 3,** über das bestehende Änderungsprotokoll.
5. **Inhalte recherchieren** — zuerst die 40 bekanntesten Brauereien, dann
   fortlaufend im Rahmen der Datenpflege bei jedem Entwicklungslauf.

## Offene Punkte / Ideen

- Bilder zur Geschichte (historische Etiketten) — erst klären, unter
  welcher Lizenz
- Geschichten zu Gasthäusern, sobald genug gepflegte Einträge existieren
