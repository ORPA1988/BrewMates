# 10 Feed

> **Status:** 🟡 teilweise — der Strom funktioniert, aber Einträge sind
> nicht löschbar, es gibt keine Statistiken und die Liste ist nicht auf
> Wachstum ausgelegt.
> **Seit:** 0.2.0, Toasts/Kommentare online seit 0.9.9 ·
> **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Der Feed ist das, was man abends durchscrollt: Was haben die anderen
getrunken, wo waren sie, was war gut? Er hält die App zwischen den eigenen
Check-ins lebendig.

## Funktion (Nutzersicht)

- Chronologischer Strom der Check-ins aller Freunde
- Je Eintrag: Bier, Brauerei, Bewertung, Notiz, Foto, Gasthaus
- **Prost** (Toast) und Kommentare — serverseitig, also für alle sichtbar
- Leerer Zustand erklärt, wie man Freunde findet

## Technische Umsetzung

- **Dateien:** `features/feed/feed_screen.dart` (nur 71 Zeilen — die
  Arbeit steckt in `widgets/checkin_card.dart`), `data/providers.dart`
  (`feedProvider`, `feedReactionsProvider`, `remoteCommentsProvider`)
- **Zusammenführung:** eigene Check-ins aus der lokalen DB plus die
  Check-ins der Freunde vom Server, nach Zeit sortiert
- **Server:** `friendCheckins()` mit `limit: 50`; RLS entscheidet, wessen
  Einträge überhaupt geliefert werden
- **Toasts/Kommentare:** `toasts` und `comments` (0001) — der Server ist
  die Wahrheit, sobald ein Check-in hochgeladen wurde

## Modularität

- **Hängt ab von:** Check-ins (02), Freunde (08)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Feature-Ordner und Navigationspunkt entfernen; die
  Check-in-Karte bleibt für das Tagebuch nötig.

## Plattformen

Alle.

## Skalierung

**Der schwächste Punkt der App** (siehe [Audit](../12-funktionsaudit.md)):

- `ListView(children: […])` baut **jeden** Eintrag sofort, auch die
  ungesehenen
- die lokale Abfrage `watchFeed()` hat **keine** Obergrenze
- serverseitig sind 50 Einträge das Ende — ohne „mehr laden" sieht man
  ältere nie
- `checkins` hat keinen Index auf `created_at`, wonach sortiert wird

Heute unauffällig, ab einigen tausend Check-ins spürbar. Die Umstellung
ist mechanisch und sollte vor dem Play-Store-Start passieren.

## Umsetzungsstatus

Der Kern läuft. Es fehlen: Löschen, Statistiken, Seitenweise-Laden.

## Umsetzungsplan

1. [Einträge löschen](19-feed-eintraege-loeschen.md)
2. `ListView.builder` + seitenweises Nachladen, lokal und serverseitig
3. Index `checkins(profile_id, created_at desc)` per Migration
4. [Statistiken](20-feed-statistiken.md) als eigener Bereich

## Offene Punkte / Ideen

- Filter im Feed (nur Crew, nur mit Foto, nur bestimmte Stile)
- Reaktionen über „Prost" hinaus — sparsam halten, sonst wird es beliebig
