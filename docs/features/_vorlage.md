# <Nummer> <Funktionsname>

> **Status:** 🔴 geplant · 🟡 teilweise · 🟢 fertig — *eine Zeile, was heute wirklich läuft*
> **Seit:** Version · **Zuletzt geprüft:** JJJJ-MM-TT

## Zielsetzung

Warum gibt es die Funktion? Welches Nutzerbedürfnis löst sie, und woran
merkt man, dass sie funktioniert? Kein Feature-Marketing — eine ehrliche
Begründung, die auch das Weglassen rechtfertigen könnte.

## Funktion (Nutzersicht)

Was sieht und tut der Mensch vor dem Bildschirm? Ablauf in Schritten,
inklusive Sonderfälle: offline, abgemeldet, leerer Zustand, Fehler.

## Technische Umsetzung

- **Dateien:** die tatsächlichen Pfade, nicht Kategorien
- **Datenmodell:** Tabellen lokal (Drift) und serverseitig (Migration)
- **Sicherheit:** RLS-Policies, Rechte, Sichtbarkeitsregeln
- **Abhängigkeiten:** Pakete und andere Funktionen

## Modularität

- **Hängt ab von:** welche Module müssen da sein
- **Wird gebraucht von:** wer bricht, wenn das hier verschwindet
- **Ausbauen:** was konkret zu tun ist, um die Funktion zu entfernen
  (Routen, Provider, Tabellen, Navigationspunkte) — wenn das nicht in
  wenigen Schritten beschreibbar ist, ist die Funktion zu tief verwoben

## Plattformen

Android · Web · Windows · iOS · macOS — je Plattform: läuft, eingeschränkt
(womit), oder gar nicht (warum). Plattformgebundene Pakete benennen.

## Skalierung

Was passiert bei 100, 10.000, 1.000.000 Einträgen bzw. Nutzern?
Abfragen ohne Limit, fehlende Indizes, eifrig gebaute Listen, Datenmengen
pro Sync — konkret, mit dem Punkt, an dem es kippt.

## Umsetzungsstatus

Was steht, was fehlt, was ist bewusst weggelassen. Bei geplanten
Funktionen: leer bzw. „noch nichts".

## Umsetzungsplan

Nummerierte Schritte in der Reihenfolge, in der sie gebaut werden — je
Schritt Ergebnis und Prüfkriterium. Bei fertigen Funktionen: nur noch die
offenen Punkte.

## Offene Punkte / Ideen

Bekannte Schwächen, Wünsche, spätere Ausbaustufen.
