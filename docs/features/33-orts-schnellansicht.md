# 33 Orts-Schnellansicht

> **Status:** 🟢 fertig · **Seit:** 0.10 ·
> **Zuletzt geprüft:** 2026-09-02

## Zielsetzung

Auf der Karte und in Entdecken tippt man einen Ort an, weil man **eine**
Sache wissen will: Ist offen? Was kostet das Halbe? Wie komme ich hin?
Eine volle Detailseite dafür zu öffnen ist ein Kontextwechsel für eine
Ein-Satz-Antwort. Das Bottom-Sheet beantwortet die Frage, ohne die Karte
zu verlassen.

## Funktion (Nutzersicht)

- Tipp auf ein Gasthaus **oder** eine Brauerei (Karte, Entdecken) →
  Sheet von unten mit: Emoji, Name, Kategorie/Ort, Verifiziert-Haken,
  Adresse, **Öffnungszeiten heute** (mit „jetzt geöffnet/geschlossen"),
  **Preise** 0,5 l / 0,3 l, Stand der letzten Änderung.
- Knöpfe: **Route** (öffnet Google Maps mit der Adresse bzw. den
  Koordinaten), **Details** (volle Seite), bei Berechtigung
  **Bearbeiten**.
- Wischen nach unten schließt; die Karte steht noch genau dort.

## Technische Umsetzung

- **Datei:** `widgets/place_quick_sheet.dart` — `PlaceQuickData` als
  gemeinsames Modell mit `fromVenue()` und `fromBrewery()`, damit
  Gasthaus und Brauerei **dasselbe** Sheet nutzen; `showPlaceQuickSheet()`
  als einziger Einstieg.
- Öffnungszeiten über `domain/opening_hours.dart`, Route über
  `core/external_links.dart` (`mapsRouteUri`), Preise aus 32.
- Liegt in `widgets/`, weil Karte (06) und Entdecken (34) es beide
  aufrufen und Features einander nicht importieren dürfen.

## UX-Hinweise

- Das Sheet ist der Grund, warum die Karte keine Detailseiten mehr
  direkt öffnet — der häufigste Fall braucht keine.
- Fehlende Daten werden **weggelassen**, nicht als „unbekannt" gezeigt:
  Ein Sheet mit drei Zeilen „keine Angabe" wäre schlechter als eines mit
  einer Zeile.
- Bei Brauereien ohne Gasthaus-Betrieb sind Öffnungszeiten meist leer;
  dann steht dort nichts — korrekt, aber der Mensch fragt sich, ob man
  hin kann. Ein Hinweis „Öffnungszeiten unbekannt — Website prüfen"
  mit Link wäre ehrlicher als Schweigen.

## Modularität

- **Hängt ab von:** Gasthäuser (05), Bier-/Brauerei-DB (04), Preise (32)
- **Wird gebraucht von:** Karte (06), Entdecken (34)
- **Ausbauen:** Aufrufe durch `context.push('/venue/…')` ersetzen.

## Plattformen

Alle. Auf Web öffnet „Route" Google Maps im neuen Tab.

## Skalierung

Nur Darstellung bereits geladener Daten.

## Umsetzungsstatus

Vollständig; bis 2026-09-02 weder in 05 noch in 06 beschrieben.

## Umsetzungsplan

1. Brauerei-Website als Link, wenn Öffnungszeiten fehlen
2. „Preis bestätigen" (siehe 32) direkt im Sheet

## Offene Punkte / Ideen

- Letzte Check-ins von Freunden an diesem Ort („Anna war vorige Woche
  hier") — bewusst nur Freunde, nie Fremde
