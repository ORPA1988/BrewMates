# 34 Entdecken

> **Status:** 🟢 fertig · **Seit:** 0.10.3 ·
> **Zuletzt geprüft:** 2026-09-02

## Zielsetzung

Wer etwas in seiner Nähe suchte, hatte drei Wege und keinen davon
naheliegend: Biere über die Bierliste, Brauereien nur über die Biersuche,
Gasthäuser über einen Knopf auf der Karte, den man kennen musste.
Entdecken ist **ein** Ort für alle drei — eine Suchzeile, drei Bereiche,
bei Orten die Sortierung nach Entfernung.

## Funktion (Nutzersicht)

- Tab **Entdecken** (Lupe) mit Suchfeld und Umschalter **Biere ·
  Brauereien · Gasthäuser**.
- **Biere:** Suche über Name, Brauerei, Stil; Tipp öffnet die Bierseite.
- **Brauereien:** ohne Suchbegriff die mit Position, nach Entfernung
  sortiert; ohne Standortfreigabe alphabetisch, und die App sagt das.
  Orte ohne Koordinaten rutschen ans Ende, statt zu verschwinden.
- **Gasthäuser:** wie Brauereien, dazu Filter **● jetzt geöffnet** und
  Kategorie (Gasthaus, Bar, Brauerei, Shop). Tipp öffnet die
  Orts-Schnellansicht (33).
- Der Standort wird still im Hintergrund geholt und ist ein Zusatz, keine
  Bedingung.

## Technische Umsetzung

- **Datei:** `features/discover/discover_screen.dart`; Route `/beers`
  (historischer Pfad, zeigt seit 0.10.3 Entdecken).
- **Daten:** `beersProvider` (Drift, lokal), `brewerySearchProvider` /
  `breweriesWithLocationProvider`, `venuesWithLocationProvider` (Cache
  aus 05); Entfernung über `latlong2`, Öffnung über `data/venue_open.dart`.
- Alles lokal — keine Serverabfrage beim Tippen. Die Community-Biere
  anderer Nutzer kommen über den Sync (16) bzw. bei der Anlage über die
  Live-Vorschläge (28).

## UX-Hinweise

- **Filter „jetzt geöffnet" ist ein Filter, die Karte färbt stattdessen.**
  Das ist Absicht: In einer Liste will man eingrenzen, auf einer Karte
  will man sehen, was zu ist — ein Loch auf der Karte erklärt nichts.
- Leere Zustände sind knapp („Kein Bier gefunden."). Es fehlt die nächste
  Handlung: „Bier anlegen" direkt aus der leeren Suche wäre der
  natürliche Weg zur Community-Datenbank.
- Die Sortierung „nach Preis" (32) fehlt hier und ist nirgends sonst.

## Modularität

- **Hängt ab von:** 04, 05, 32, 33
- **Wird gebraucht von:** nichts — Einstiegspunkt
- **Ausbauen:** Route `/beers` auf eine der drei Teillisten legen.

## Plattformen

Alle. Auf Web und Desktop ohne Standort (Browser fragt; Desktop meist
ohne) — dann alphabetisch, wie angezeigt.

## Skalierung

Lokale Streams über Drift; 699 Biere und 162 Brauereien sind unkritisch.
Bei Gasthäusern wächst der Cache mit der Community; die Liste ist faul
(`ListView.builder`).

## Umsetzungsstatus

Vollständig. Der alte Bierbildschirm (`beers_screen.dart`) und die alte
Gasthausliste (`venues_list_screen.dart`, Route `/venues`) waren nach dem
Umbau **tot** — von keiner Stelle mehr erreichbar — und wurden am
2026-09-02 entfernt.

## Umsetzungsplan

1. „Bier anlegen" / „Gasthaus anlegen" aus der leeren Suche
2. Sortierung nach Preis im Bereich Gasthäuser

## Offene Punkte / Ideen

- Zuletzt gesuchte Begriffe als Chips über der Suchzeile
