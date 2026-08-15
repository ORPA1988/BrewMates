# 13 Statistiken & Tagebuch

> **Status:** 🟢 fertig — Tagebuch mit Suche und Seitenladen, Auswertung
> in [Funktion 20](20-feed-statistiken.md).
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

Seit 0.9.14 lädt das Tagebuch 30er-Seiten und baut faul. Genau hier
wächst die Datenmenge am zuverlässigsten — ein Tagebuch, das nach zwei
Jahren Nutzung hakt, wäre ein Eigentor.

Die Suche läuft dabei **in der Abfrage** (`watchFeed(search:)`), nicht
über das geladene Fenster. Der bequemere Weg hätte die Suche schleichend
verschlechtert: Sie hätte nur noch gefunden, was ohnehin schon geladen
war. Die Gesamtzahl im Kopfbereich kommt aus einer eigenen
Zählabfrage, damit sie den echten Bestand nennt und nicht die Fenstergröße.

## Umsetzungsstatus

Vollständig. Die Profilzähler bleiben als Schnellblick; die eigentliche
Auswertung lebt seit 0.9.15 in [Funktion 20](20-feed-statistiken.md).

## Umsetzungsplan

1. ~~[Statistiken](20-feed-statistiken.md) mit Filtern und Aufteilungen~~
   — erledigt (0.9.15)
2. ~~Tagebuch auf faules Bauen und seitenweises Laden umstellen~~ —
   erledigt (0.9.14)
3. Filter im Tagebuch (Zeitraum, Stil, Bewertung)

## Offene Punkte / Ideen

- „Dein Bierjahr" als teilbarer Rückblick
- Export der eigenen Daten (CSV) — gehört ohnehin zur Datenhoheit
