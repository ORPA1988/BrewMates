# 10 Feed

> **Status:** 🟢 fertig — Strom, Löschen, Seitenladen und Einstieg in die
> Statistik.
> **Seit:** 0.2.0, Toasts/Kommentare online seit 0.9.9 ·
> **Zuletzt geprüft:** 2026-09-03
>
> **Seit 0.10.12 steht das Etikett links neben dem Namen** — vorher stand
> dort gar nichts, und in allen übrigen Listen dasselbe 🍺 vor jedem
> Eintrag. Ein Zeichen, das bei allen gleich ist, trägt keine Information;
> ein Etikett erkennt man schneller, als man einen Namen liest. Das Bild
> ist tippbar wie der Name (`widgets/beer_thumbnail.dart`).
>
> **Ebenfalls seit 0.10.12:** Nach unten ziehen lädt neu — das fehlte
> ausgerechnet auf dem einen Bildschirm, bei dem man wissen will, ob
> gerade jemand etwas getrunken hat. Und ein Check-in-Foto lässt sich
> antippen und groß ansehen (`widgets/foto_ansicht.dart`); im Feed ist es
> 200 Punkte hoch und beschnitten, was auf dem Etikett steht, sah man
> dort nicht.

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

### Toast nur, wenn der Server ihn hat (2026-09-02)

Der Toast auf einen hochgeladenen Check-in wurde lokal umgeschaltet,
egal was der Server sagte; beim nächsten Laden sprang er zurück.
`toggleServerToast` gibt jetzt `null` zurück, wenn der Server ablehnt —
dann wird nichts gespiegelt und die Karte sagt „Konnte nicht gesendet
werden".

## Modularität

- **Hängt ab von:** Check-ins (02), Freunde (08)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Feature-Ordner und Navigationspunkt entfernen; die
  Check-in-Karte bleibt für das Tagebuch nötig.

## Plattformen

Alle.

## Skalierung

War der schwächste Punkt der App, seit 0.9.14 entschärft:

- `watchFeed(limit:)` statt unbegrenzter Abfrage; Feed und Tagebuch laden
  30er-Seiten und wachsen beim Scrollen (`PagedCheckinList`)
- serverseitig folgt `friendCheckins(limit:)` demselben Fenster — „mehr
  laden" holt auch ältere Einträge der Freunde nach
- `ListView.builder` statt `children:` — bei jedem Rebuild entstehen nur
  noch die sichtbaren Karten
- Migration 0020 bringt den Index `checkins(created_at desc)`, den die
  Feed-Abfrage braucht (der vorhandene `(profile_id, created_at desc)`
  hilft ihr nicht, weil `profile_id` per `<>` gefiltert wird)

Der Upload-Assistent liest bewusst weiter den **ungekürzten** Bestand:
Sonst bliebe genau der alte, offline entstandene Check-in unentdeckt, für
den es ihn gibt.

## Umsetzungsstatus

Vollständig.

## Umsetzungsplan

1. ~~[Einträge löschen](19-feed-eintraege-loeschen.md)~~ — erledigt
2. ~~`ListView.builder` + seitenweises Nachladen~~ — erledigt
3. ~~Index per Migration~~ — erledigt (0020)
4. ~~[Statistiken](20-feed-statistiken.md) als eigener Bereich~~ — erledigt (0.9.15)

## Offene Punkte / Ideen

- Filter im Feed (nur Crew, nur mit Foto, nur bestimmte Stile)
- Reaktionen über „Prost" hinaus — sparsam halten, sonst wird es beliebig
