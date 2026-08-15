# 13 Statistiken & Tagebuch

> **Status:** 🟡 teilweise — Tagebuch mit Suche steht, die Auswertung
> beschränkt sich auf vier Zähler.
> **Seit:** 0.2.0, Wochen-Serie seit 0.9.12 · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Das Tagebuch ist der private Gegenpol zum Feed: alles, was man selbst
getrunken hat, durchsuchbar und ohne Publikum. Es ist der Grund, warum
Menschen die App über Jahre behalten — gesammelte Erinnerungen wirft
niemand weg.

## Funktion (Nutzersicht)

- Chronologische Liste aller eigenen Check-ins mit Volltextsuche
- Profil zeigt: Anzahl Check-ins, verschiedene Stile, Länder,
  🔥 Wochen-Serie
- Wunschliste und Abzeichen sind von hier erreichbar

**Die Wochen-Serie** zählt Wochen mit mindestens einem Check-in — bewusst
wöchentlich statt täglich: Eine Tagesserie erzeugt Druck, jeden Tag zu
trinken. Die laufende Woche bricht die Serie noch nicht.

## Technische Umsetzung

- **Dateien:** `features/profile/profile_screen.dart`, `diary_screen.dart`,
  `domain/streak.dart`
- **Berechnung:** `weeklyStreak()` arbeitet auf reinen Datumslisten, ohne
  Datenbank — vollständig testbar (6 Tests)
- **Daten:** alles aus der lokalen Drift-DB, also offline verfügbar

## Modularität

- **Hängt ab von:** Check-ins (02)
- **Wird gebraucht von:** Abzeichen (Wochen-Serie)
- **Ausbauen:** Bildschirme entfernen; `domain/streak.dart` bleibt für das
  Abzeichen nötig.

## Plattformen

Alle.

## Skalierung

Das Tagebuch lädt alle eigenen Check-ins und baut die Liste vollständig
auf (siehe [Audit](../12-funktionsaudit.md)). Genau hier wächst die
Datenmenge am zuverlässigsten — ein Tagebuch, das nach zwei Jahren
Nutzung hakt, ist ein Eigentor. Umstellung auf faules Bauen und
seitenweises Laden ist überfällig, bevor jemand so viele Daten hat.

## Umsetzungsstatus

Das Tagebuch ist vollständig. Die Statistik ist es nicht: Vier Zähler,
wo alle Daten für echte Auswertungen längst vorliegen — Land, Stil,
Gebinde, Zeitpunkt, Gasthaus.

## Umsetzungsplan

1. [Statistiken](20-feed-statistiken.md) mit Filtern und Aufteilungen
2. Tagebuch auf faules Bauen und seitenweises Laden umstellen
3. Filter im Tagebuch (Zeitraum, Stil, Bewertung)

## Offene Punkte / Ideen

- „Dein Bierjahr" als teilbarer Rückblick
- Export der eigenen Daten (CSV) — gehört ohnehin zur Datenhoheit
