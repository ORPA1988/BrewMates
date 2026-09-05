# 41 Sortieren in Entdecken

> **Status:** 🟡 in Arbeit — Gasthäuser konnten es längst, Biere und
> Brauereien bekommen es jetzt.
> **Seit:** 0.10.16 · **Zuletzt geprüft:** 2026-09-05
>
> Aus Meldung [#145](https://github.com/ORPA1988/BrewMates/issues/145):
> „Bier und Brauereien sollen nach verschiedenen Kriterien wie z. B.
> Entfernung vom aktuellen Standort sortiert werden können."

## Zielsetzung

Der [Entdecken-Bildschirm](34-entdecken.md) hat drei Bereiche, und sie
konnten bisher **drei verschiedene Dinge**:

| Bereich | vorher |
|---|---|
| Gasthäuser | vier Sortierungen zur Wahl (Nähe, A–Z, Preis, Aktuell) |
| Brauereien | immer nach Entfernung, ohne Wahl |
| Biere | immer alphabetisch, ohne Wahl |

Das ist nicht drei Mal die richtige Entscheidung, sondern eine gewachsene
Ungleichheit. Wer in einer Liste eine Chipleiste zum Sortieren gelernt
hat, sucht sie in der nächsten.

**Woran man merkt, dass es funktioniert:** „Welche Brauerei ist von hier
die nächste?" und „welches Bier hat am wenigsten Alkohol?" sind beide
mit einem Tipp beantwortet, in derselben Leiste an derselben Stelle.

## Funktion (Nutzersicht)

Über jeder Liste dieselbe Chipleiste, je Bereich mit den Kriterien, die
dort etwas bedeuten:

- **Biere:** A–Z · 📍 Nähe (über die Brauerei) · % Alkohol · Stil
- **Brauereien:** 📍 Nähe · A–Z
- **Gasthäuser:** 📍 Nähe · A–Z · € Preis · Aktuell *(unverändert)*

**Ohne Standort ist „Nähe" ausgegraut** statt weg — mit einem Hinweis,
warum. Das ist die Regel, die bei den Gasthäusern schon galt: Ein Chip,
der verschwindet, sieht aus wie ein Fehler; einer, der ausgegraut ist und
sich erklärt, ist eine Auskunft.

**Ein Bier hat keinen Ort** — es hat eine Brauerei, und die hat einen.
„Nähe" bei Bieren heißt deshalb: die Entfernung zu ihrer Brauerei. Das
steht auch so in der Zeile, damit niemand glaubt, das Bier sei um die
Ecke zu kaufen.

## Technische Umsetzung

- **Neu:** `data/beer_sort.dart` — `BeerSort`, `beerSortLabel`,
  `sortBeers` und `sortBreweries`. Eigene Datei statt Anbau an
  `venue_open.dart` (Regel G: neue Funktionen bekommen eigene Dateien);
  reine Funktionen, ohne Widgets testbar, wie das Vorbild `sortVenues`.
- **Geändert:** `features/discover/discover_screen.dart` — die
  Sortierleiste gilt jetzt für alle drei Bereiche, je Bereich mit
  eigenem Zustand. Ein Wechsel des Bereichs setzt die Sortierung nicht
  zurück: Wer bei Bieren nach Nähe sortiert hat, findet das beim
  Zurückwechseln wieder.
- **Nullwerte sortieren ans Ende**, nie heraus — dieselbe Regel wie bei
  `sortVenues`: Ein Bier ohne Alkoholangabe ist trotzdem ein Bier.
- **Bei gleichem Rang entscheidet der Name.** `sort` ist in Dart nicht
  stabil; ohne diesen Zweitschlüssel springt die Liste bei jedem
  Neuzeichnen.

## Modularität

- **Hängt ab von:** Bier- und Brauereidatenbank (04), Standortdienst
- **Wird gebraucht von:** nur dem Entdecken-Bildschirm
- **Ausbauen:** `beer_sort.dart` löschen, die Chipleiste auf Gasthäuser
  zurückschneiden. Die Listen funktionieren unverändert weiter.

## Plattformen

Alle. Ohne Standortfreigabe fehlt genau ein Kriterium, der Rest
funktioniert — im Browser wie am Telefon.

## Skalierung

Sortiert wird im Speicher über die geladene Liste (660 Biere, 137
Brauereien). Das ist unkritisch. Würde die Datenbank serverseitig
durchsuchbar (Backlog C-1), zöge die Sortierung mit in die Abfrage.

## Umsetzungsplan

| Schritt | Was | Prüfkriterium |
|---|---|---|
| 1 | `data/beer_sort.dart` mit Tests | Unit-Tests: Nullwerte ans Ende, Name als Zweitschlüssel |
| 2 | Chipleiste für alle drei Bereiche | Widget-Test: „Nähe" ohne Standort ausgegraut |
| 3 | Entfernung in der Bierzeile anschreiben | sichtbar, dass sie zur Brauerei gehört |

## Bewusst nicht

- **Keine Sortierung nach Bewertung.** Die redaktionelle Einschätzung
  ist keine Messung (siehe [Funktion 04](04-bier-und-brauerei-datenbank.md)),
  und echte Bewertungen gibt es erst für wenige Biere. Eine Rangliste
  daraus wäre eine Behauptung.
- **Keine Umkehr der Richtung** (auf-/absteigend). Jedes Kriterium hat
  eine offensichtliche Richtung; ein zweiter Tipp, der sie dreht, kostet
  mehr Erklärung als er wert ist.
