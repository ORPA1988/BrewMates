# 14 Wunschliste

> **Status:** 🟢 fertig — merken, abhaken, über Geräte hinweg gesichert.
> **Seit:** 0.3.0, Cloud-Sicherung seit 0.9.8 (0016) ·
> **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Man hört von einem Bier, will es probieren — und hat es zwei Wochen später
vergessen. Die Wunschliste ist der Zettel dafür, und sie schließt den
Kreis zur Entdeckung: Was drauf steht, sucht man gezielt.

## Funktion (Nutzersicht)

- Auf jeder Bierseite ein Merken-Symbol
- Eigene Liste mit direktem Weg zum Check-in
- Einträge lassen sich entfernen
- Bleibt bei Gerätewechsel erhalten

## Technische Umsetzung

- **Dateien:** `features/profile/wishlist_screen.dart`,
  `data/providers.dart`
- **Lokal:** Drift-Tabelle `WishlistItems`
- **Server:** `wishlist_items` (0016) mit `beer_key`; die Wiederherstellung
  führt lokale und Serverliste zusammen (Vereinigung, wiederholbar)

Der Abgleich zum Server ist best-effort — die Liste funktioniert offline
vollständig, die Sicherung ist Zugabe.

## Modularität

- **Hängt ab von:** Bierdatenbank (04)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Bildschirm, Merken-Symbol und Provider entfernen; Tabellen
  können bleiben.

## Plattformen

Alle.

## Skalierung

Unkritisch — Wunschlisten sind naturgemäß kurz.

## Umsetzungsstatus

Vollständig.

## Umsetzungsplan

Keiner. Mögliche Ergänzung: Hinweis, wenn ein Bier von der Wunschliste in
einem Gasthaus in der Nähe ausgeschenkt wird — das setzt allerdings
gepflegte Getränkekarten voraus, die es nicht gibt.

## Offene Punkte / Ideen

- Wunschliste mit Freunden teilen (Geschenkideen)
- Automatischer Vorschlag aus Stilen, die man mag
