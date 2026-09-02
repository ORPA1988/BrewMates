# 32 Bierpreise und Preis-Radar

> **Status:** 🟢 fertig · **Seit:** 0.9.x ·
> **Zuletzt geprüft:** 2026-09-02

## Zielsetzung

Die Frage im Wirtshaus ist selten „welches Bier", sondern oft „was kostet
das Halbe". Die Preise gehören zu den wenigen Daten, die nur Menschen
vor Ort liefern können — kein Katalog hat sie. Wer sie pflegt, hilft
allen; wer sie sieht, wählt bewusster.

## Funktion (Nutzersicht)

- Beim Gasthaus lassen sich **Preis 0,5 l** und **Preis 0,3 l** eintragen
  (in Euro, mit Komma), wie alle Gasthausdaten für alle sichtbar.
- **Preis-Radar auf der Karte:** Ab Zoomstufe 12 steht der 0,5-l-Preis
  direkt am Namensschild des Gasthauses („Bräustüberl · 4,20").
- In der **Orts-Schnellansicht** (33) stehen beide Preise mit Datum der
  letzten Änderung.

## Technische Umsetzung

- **Dateien:** `features/venues/venue_edit_screen.dart` (Eingabe,
  Validierung 0–99 €), `features/map/map_screen.dart` (Radar-Label ab
  `_zoom >= 12`), `widgets/place_quick_sheet.dart` (Anzeige),
  `data/db/database.dart` (`priceHalfL`, `priceThirdL`)
- **Server:** Spalten `venues.price_half_l`, `price_third_l`; Änderungen
  laufen wie jede Gasthaus-Änderung über RLS (Ersteller oder Stufe ≥ 2)
  und die Offline-Warteschlange `venue_edit_queue` (siehe 05).
- Kein Preisverlauf: Es gilt der zuletzt eingetragene Wert. Das Datum
  der letzten Änderung ist die einzige Einordnung.

## UX-Hinweise

- Der Radar zeigt **nur** Gasthäuser mit Preis — ein Haus ohne Eintrag
  trägt schlicht keinen Wert, keinen Platzhalter. Das ist richtig: Ein
  „?" am Schild wäre Lärm.
- Ein alter Preis sieht aus wie ein aktueller. Das Datum steht nur in
  der Schnellansicht. Ab einem Alter von, sagen wir, einem Jahr sollte
  das Schild es zeigen.
- Es gibt keine Stelle, an der man „günstigstes Halbe in der Nähe"
  fragen kann — die Sortierung nach Preis stand nur im inzwischen toten
  `beers_screen.dart` und ist mit dessen Entfernung (2026-09-02) weg.
  Sie gehört nach Entdecken (34).

## Modularität

- **Hängt ab von:** Gasthäuser (05), Karte (06)
- **Wird gebraucht von:** Orts-Schnellansicht (33)
- **Ausbauen:** zwei Spalten, zwei Eingabefelder, ein Label — jeweils
  eine Stelle.

## Plattformen

Alle.

## Skalierung

Unkritisch; Teil der Gasthaus-Zeile.

## Umsetzungsstatus

Vollständig, aber bis 2026-09-02 in keinem Dokument beschrieben (05
erwähnte die Preise nicht).

## Umsetzungsplan

1. Sortierung „nach Preis" im Bereich Gasthäuser von Entdecken
2. Alterskennzeichnung am Radar-Schild (z. B. ausgegraut nach 12 Monaten)

## Offene Punkte / Ideen

- „Preis bestätigen" mit einem Tipp, ohne den Wert neu einzugeben —
  aktualisiert nur das Datum
