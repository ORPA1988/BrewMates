# 05 Gasthäuser

> **Status:** 🟢 fertig — gemeinsame Datenbank, Öffnungszeiten, Pflege
> auch offline.
> **Seit:** 0.9.0 (0011), Öffnungszeiten 0.9.7 (0015) ·
> **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Ein Check-in ohne Ort ist eine halbe Erinnerung. Gasthäuser geben den
Check-ins einen Platz, füllen die Karte und sind die Voraussetzung dafür,
dass Beacons etwas bedeuten: „Ich bin im Augustiner" statt „ich bin
irgendwo".

Anders als die Bierdatenbank ist das ein echtes Gemeinschaftswerk — die
Einträge kommen von Nutzern, nicht aus dem Repository.

## Funktion (Nutzersicht)

- Beim Check-in ein Gasthaus wählen (Nähe zuerst) oder neu anlegen
- Gasthausliste mit Sortierung nach Entfernung, Name oder Beliebtheit
- Detailansicht: Adresse, Öffnungszeiten mit „jetzt geöffnet", Karte
- Bearbeiten ab Vertrauensstufe 2; jede Änderung landet im Protokoll
- **Offline nutzbar:** Anlegen und Bearbeiten wirken sofort, der Abgleich
  läuft später

Beim Anlegen erscheinen ähnliche vorhandene Häuser unter der Namenszeile
und sind **anklickbar** — siehe [Live-Vorschläge](28-live-vorschlaege.md).
Vorher standen sie als toter Text dort und kündigten das Duplikat an,
statt es zu verhindern.

## Technische Umsetzung

- **Dateien:** `features/discover/discover_screen.dart` (Liste, seit 0.10.3; die alte `venues_list_screen.dart` fiel am 2026-09-02),
  `venue_edit_screen.dart`, `widgets/venue_picker.dart`,
  `widgets/place_quick_sheet.dart`, `data/venue_sync.dart`,
  `data/venue_queue.dart`, `domain/opening_hours.dart`
- **Server:** `venues` (0011) mit PostGIS-Position,
  `opening_hours_json` (0015)
- **Offline-Warteschlange:** Drift v8 — `venue_edit_queue`, FIFO,
  „letzte Änderung gewinnt", Wiedergabe zu Beginn von `VenueSync.sync()`.
  Neuanlagen bekommen bis zum Hochladen eine `local-…`-Ersatz-ID.

**Dieses Muster ist die Vorlage** für alle künftigen Schreibpfade, die
offline funktionieren sollen — es ist erprobt und die Wiedergabe ist
idempotent.

### Aufgegangen in „Entdecken" (2026-08-15)

Die eigene Gasthausliste gibt es nicht mehr. Sie war nur über einen Knopf
auf der Karte erreichbar — wer ihn nicht fand, fand die Liste nicht.

„Entdecken" führt jetzt **Biere, Brauereien und Gasthäuser** an einer
Stelle zusammen: eine Suchzeile, drei Bereiche, und bei Orten die
Sortierung **nach Entfernung**. Die Filter der alten Liste (Kategorie,
„jetzt geöffnet") sind mitgekommen.

Der Standort wird still im Hintergrund geholt und ist ein Zusatz, keine
Bedingung: Ohne Freigabe sortiert die Liste alphabetisch weiter und sagt
das auch. Orte ohne Koordinaten rutschen ans Ende, statt zu verschwinden —
eine Brauerei ohne Position ist trotzdem eine Brauerei.

## Modularität

- **Hängt ab von:** Konto (01), Vertrauensstufen (15)
- **Wird gebraucht von:** Check-ins (optional), Karte, Sessions
- **Ausbauen:** Feature-Ordner, Sync und Warteschlange entfernen,
  `venueId`/`venueName` am Check-in leer lassen. Check-ins funktionieren
  ohne Gasthaus.

## Plattformen

Alle. Die Nähe-Sortierung braucht `geolocator` — ohne Standort greift die
alphabetische Sortierung.

## Skalierung

`venues_list_screen` baut alle Einträge sofort (siehe
[Audit](../12-funktionsaudit.md)) — bei einigen hundert Gasthäusern
umzustellen. Die Umkreissuche über PostGIS ist indexgestützt und
unkritisch.

Die Konfliktlösung „letzte Änderung gewinnt" ist grob: Zwei Personen, die
zeitgleich verschiedene Felder ändern, überschreiben einander. Bei der
heutigen Nutzung unwahrscheinlich, aber bekannt.

## Umsetzungsstatus

Vollständig für den vorgesehenen Zweck.

## Umsetzungsplan

1. Liste auf faules Bauen umstellen
2. Feldweises Zusammenführen statt „letzte Änderung gewinnt", wenn die
   Nutzung steigt
3. Später: Verifizierte Wirte nach dem Muster von
   [Brauerei-Besitz](25-brauerei-besitz.md)

## Offene Punkte / Ideen

- Fotos zu Gasthäusern
- Import aus OpenStreetMap als Startbestand — Lizenzfrage vorher klären
