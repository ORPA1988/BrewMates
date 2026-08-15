# 20 Feed-Statistiken

> **Status:** 🟢 fertig — eigener Bereich mit Mengen, Aufteilungen,
> Zeitraum und Filtern.
> **Seit:** 0.9.15-beta · **Zuletzt geprüft:** 2026-08-15

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

- **Gesamt:** Check-ins, verschiedene Biere, Brauereien, Orte, Menge in
  Litern, Ø Bewertung, alkoholfreie
- **Aufteilungen** als Balken, jeweils absteigend:
  Land · Stil (Top 10) · Gebinde (Fass, Flasche, Dose, Growler,
  „ohne Angabe") · Brauerei (Top 10)
- **Zeitraum:** dieser Monat · dieses Jahr · alles
- **Filter** für Land und Stil, kombinierbar mit dem Zeitraum — „nur
  Österreich, nur Pils, dieses Jahr"
- **Verlauf:** Check-ins je Monat als schlichte Balkenreihe. Monate ohne
  Eintrag fehlen, statt als Null zu erscheinen — kein Eintrag ist kein
  Nullwert.

Ausgewertet werden **eigene** Check-ins. Das ist die ehrliche Grenze:
Von Freunden liegt nur das geladene Fenster vor, eine Auswertung darüber
wäre falsch statt unvollständig.

Orte erscheinen als Zahl, aber nicht als Balken: Der Gasthausname ist am
Check-in denormalisiert, Tippfehler und Schreibvarianten würden dieselbe
Wirtschaft mehrfach auflisten.

## Technische Umsetzung

- **Neu:** `domain/statistics.dart` — reine Auswertung über
  `List<CheckinDetails>`, ohne Flutter und ohne Datenbank, damit
  vollständig testbar (`computeStats`, `CheckinStats`)
- **Neu:** `features/stats/stats_screen.dart` + `stats_providers.dart`
  (eigene Provider-Datei statt Anbau an die Sammelstelle, siehe docs/11)
- **Geändert:** `features/checkin/checkin_screen.dart` (Mengenauswahl),
  `core/format.dart` (`formatVolume`, `formatLitres`), Drift v11,
  Migration 0022 für `checkins.volume_ml`, Upload- und
  Wiederherstellungspfad

Die Ergebnisklasse heißt `CheckinStats`, nicht `BeerStats` — den Namen
belegt bereits das Join-Modell für Bier-Bewertungen.

**Die fehlende Zutat war die Menge.** `ServingStyle` (Gebinde) gab es
bereits, aber keine Füllmenge. Neu: `volume_ml` als Ganzzahl, im Check-in
über Auswahlchips gesetzt (0,2 · 0,25 · 0,33 · 0,4 · 0,5 · 1 l),
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

## Umsetzungsstatus

Vollständig. Erreichbar über das Balkensymbol im Feed und die Kachel
„Statistik" im Profil.

Die Menge wird beim Check-in über Auswahlchips gesetzt (0,2 · 0,25 ·
0,33 · 0,4 · 0,5 · 1 l), vorbelegt nach Gebinde, bis der Mensch selbst
wählt. Sie wandert mit dem Check-in in die Cloud und kehrt bei der
Wiederherstellung zurück — sonst wäre sie beim Gerätewechsel weg.

Abgesichert durch `test/statistics_test.dart` (15 Tests): Summen,
Schätzung fehlender Mengen, Zeiträume, Filter einzeln und kombiniert,
Sortierung samt Gleichstand, Zählung verschiedener Biere/Brauereien/Orte,
Durchschnitt nur über Bewertetes, Monatsverlauf, Formatierung.

## Umsetzungsplan

Erledigt.

## Offene Punkte / Ideen

- Freier Zeitraum („von … bis") neben Monat/Jahr/alles
- Eigene Füllmenge eintippen, wenn keiner der Chips passt
- „Dein Bierjahr" als teilbarer Jahresrückblick — die Auswertung von hier
  ist die Grundlage dafür
- Crew-Statistiken, sobald es einen Crew-Feed gibt
