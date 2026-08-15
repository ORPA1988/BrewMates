# 20 Feed-Statistiken

> **Status:** 🔴 geplant — heute gibt es nur die vier Zähler im Profil.
> **Geplant für:** 0.9.15-beta · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Wer ein Jahr lang Check-ins sammelt, will irgendwann wissen, was dabei
herausgekommen ist: Wie viel war das eigentlich? Woher kamen die Biere?
Was trinke ich am liebsten, und hat sich das verändert?

Die Daten liegen fast vollständig vor — sie werden nur nicht ausgewertet.
Das ist die günstigste Funktion im ganzen Plan: viel Ertrag, kaum neue
Substanz.

**Grundsatz aus der Produktvision:** Ausgewertet wird **Vielfalt und
Erinnerung**, nicht Leistung. Liter werden gezeigt, weil die Frage
naheliegt — aber nie als Bestenliste gegen andere und nie mit einer
Zielvorgabe. Ein Rückblick, kein Wettbewerb.

## Funktion (Nutzersicht)

Ein Statistik-Bereich, erreichbar aus dem Feed und aus dem Profil:

- **Gesamt:** Anzahl Check-ins, verschiedene Biere, verschiedene
  Brauereien, geschätzte Menge in Litern
- **Aufteilungen** als Balken, jeweils absteigend:
  Land · Stil · Gebinde (Fass, Flasche, Dose, Growler) · Brauerei ·
  Gasthaus
- **Zeitraum** wählbar: dieser Monat · dieses Jahr · alles · frei
- **Filter** kombinierbar mit den Aufteilungen — „nur Österreich, nur
  Fassbier, dieses Jahr"
- **Verlauf:** Check-ins je Monat als schlichte Balkenreihe

Ausgewertet werden zunächst **eigene** Check-ins. Das ist die ehrliche
Grenze: Freundesdaten liegen nur als letzte 50 Einträge vor, eine
Auswertung darüber wäre falsch statt unvollständig.

## Technische Umsetzung

- **Neu:** `domain/statistics.dart` — reine Auswertung über
  `List<CheckinDetails>`, ohne Flutter und ohne Datenbank, damit
  vollständig testbar
- **Neu:** `features/stats/stats_screen.dart` + `stats_providers.dart`
- **Geändert:** `features/checkin/checkin_screen.dart` (Mengenauswahl),
  Drift v11, Migration für `checkins.volume_ml`

**Die fehlende Zutat ist die Menge.** `ServingStyle` (Gebinde) gibt es
bereits, aber keine Füllmenge. Neu: `volume_ml` als Ganzzahl, im Check-in
über Schnellauswahl gesetzt (0,25 · 0,33 · 0,5 · 1,0 l · eigener Wert),
vorbelegt nach Gebinde. Alte Check-ins ohne Angabe zählen mit einem
Schätzwert je Gebinde und werden als geschätzt gekennzeichnet — eine
Literzahl, die so tut, als wäre sie gemessen, wäre eine Lüge.

**Keine Diagramm-Bibliothek.** Die Balken entstehen aus
`Container`-Breiten. Das hält die App plattformunabhängig und spart ein
Paket, das auf einer der fünf Zielplattformen erfahrungsgemäß klemmt.

## Modularität

- **Hängt ab von:** Check-ins (02), Bierdatenbank (04, für Land und Stil)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Ordner `features/stats/` und `domain/statistics.dart`
  löschen, zwei Einstiegspunkte entfernen. `volume_ml` darf bleiben — es
  ist auch ohne Auswertung eine sinnvolle Angabe.

## Plattformen

Alle. Reine Rechnung und Darstellung.

## Skalierung

Die Auswertung läuft heute über alle eigenen Check-ins im Speicher. Bei
einigen tausend Einträgen ist das noch unauffällig, darüber gehört die
Summenbildung in SQL (Drift kann `groupBy`). Der Schnitt ist vorbereitet,
weil `domain/statistics.dart` nur eine Liste bekommt: Die Quelle lässt sich
später austauschen, ohne die Darstellung anzufassen.

## Umsetzungsplan

1. **Menge erfassen.** Drift v11 + Migration `checkins.volume_ml`,
   Schnellauswahl im Check-in-Formular, Vorbelegung nach Gebinde.
   *Prüfkriterium:* Check-in speichert die Menge, alte Einträge bleiben
   gültig.
2. **Auswertung.** `domain/statistics.dart`: Summen, Aufteilungen,
   Zeitraumfilter.
   *Prüfkriterium:* Unit-Tests mit erfundenen Check-ins, inklusive
   Schätzwerten für fehlende Mengen und leerer Liste.
3. **Darstellung.** Statistik-Bildschirm mit Balken, Zeitraumwahl,
   Filtern.
   *Prüfkriterium:* Widget-Test — Filter verändert die Zahlen; leerer
   Zustand erklärt sich selbst.
4. **Einstiege** aus Feed und Profil, Kennzeichnung geschätzter Mengen.

## Offene Punkte / Ideen

- „Dein Bierjahr" als teilbarer Jahresrückblick — die Auswertung von hier
  ist die Grundlage dafür
- Crew-Statistiken, sobald es einen Crew-Feed gibt
