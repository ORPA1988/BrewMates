# 06 Karte

> **Status:** 🟢 fertig — Freunde, Brauereien, Gasthäuser; Fremde nur als
> Zahl.
> **Seit:** 0.5.0 · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Die Karte beantwortet die Frage, die den Abend entscheidet: „Ist gerade
jemand unterwegs, und wo?" Sie ist der sichtbarste Unterschied zu einer
reinen Protokoll-App.

## Funktion (Nutzersicht)

- Freunde mit aktivem Beacon als Punkte, mit Gasthaus und Nachricht
- Brauereien als eigene, abschaltbare Ebene (herausgezoomt als Punkte)
- Gasthäuser aus der gemeinsamen Datenbank
- Oben rechts ein Zähler für alle übrigen aktiven Nutzer

**Die härteste Regel der App:** Nicht-Freunde erscheinen **nie** mit
Position — nur als Zahl. Das ist kein Anzeigedetail, sondern
serverseitig durchgesetzt: Die Positionen fremder Sessions verlassen die
Datenbank gar nicht erst. Das Wording dafür steht zentral in
`activeUsersLabel()`, damit es nirgends versehentlich anders klingt.

## Technische Umsetzung

- **Dateien:** `features/map/map_screen.dart`, `data/location_service.dart`
- **Karte:** `flutter_map` mit OpenStreetMap-Kacheln — kein Google-SDK,
  läuft dadurch auch auf Desktop und im Browser
- **Server:** `sessions.location` als PostGIS-Punkt (bei Stealth `null`),
  RLS filtert nach Freundschaft; `count_other_active_sessions()` liefert
  die reine Zahl
- **Standort:** `geolocator`, Berechtigung wird erklärt, bevor sie
  angefragt wird

## Modularität

- **Hängt ab von:** Sessions (07), Freunde (08), Gasthäuser (05),
  Bierdatenbank (04)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Feature-Ordner und Navigationspunkt entfernen. Die
  Sessions selbst blieben funktionsfähig — es fehlte nur die Übersicht.

## Plattformen

Alle. Ohne Standortberechtigung zeigt die Karte den zuletzt bekannten
Ausschnitt statt einer Fehlermeldung; auf Desktop entfällt die
Ortung.

## Skalierung

OpenStreetMap-Kacheln haben eine Nutzungsrichtlinie — bei nennenswerter
Nutzerzahl braucht es einen eigenen oder bezahlten Kachel-Server. Das ist
der erste externe Kostenpunkt, den Wachstum auslöst.

Die Freundes-Positionen sind durch die Freundeszahl begrenzt und damit
unkritisch; der Zähler ist eine einzige Aggregatabfrage.

## Umsetzungsstatus

Vollständig.

## Umsetzungsplan

1. Sichtbarkeit nach [Freundeskreisen](24-freundeskreise.md) abstufen —
   Bekannte sehen künftig, *dass* jemand unterwegs ist, nicht *wo*
2. Restlaufzeit der Beacons anzeigen ([Funktion 23](23-beacon-laufzeit.md))

## Offene Punkte / Ideen

- Heatmap der eigenen Check-ins („wo war ich überall?")
- Kachel-Server klären, bevor die Nutzerzahl es erzwingt
