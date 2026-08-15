# 19 Feed-Einträge löschen

> **Status:** 🔴 geplant — noch nichts umgesetzt. Serverseitig ist der Weg
> bereits offen (`checkins_delete`-Policy aus 0001), es fehlt alles davor.
> **Geplant für:** 0.9.14-beta · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Ein Check-in ist eine Erinnerung, kein Vertrag. Wer das falsche Bier
scannt, sich vertippt oder einen Abend schlicht nicht dokumentiert haben
möchte, muss ihn wieder entfernen können — heute geht das nur, indem man
das ganze Konto löscht. Das ist die deutlichste Lücke im Bestand.

Es geht dabei auch um Vertrauen: Eine App, die Trinkverhalten und Orte
aufzeichnet, muss den Rückwärtsgang beherrschen. Wer nicht löschen kann,
checkt im Zweifel gar nicht erst ein.

## Funktion (Nutzersicht)

- **Eigene** Karten im Feed und im Tagebuch bekommen ein Menü
  („⋯" → „Check-in löschen"). Fremde Karten nie.
- Rückfrage mit dem Namen des Biers, damit nicht der falsche erwischt wird.
- Nach dem Löschen erscheint kurz „Rückgängig" — die häufigste Reaktion auf
  ein versehentliches Löschen ist der Wunsch, es sofort zurückzunehmen.
- Offline: Das Löschen wirkt sofort, der Server erfährt es beim nächsten
  Abgleich (wie bei der Gasthaus-Pflege).
- Ein Foto zum Check-in verschwindet mit.

**Was bewusst bleibt:** Bereits erhaltene Abzeichen und abgeschlossene
Challenges werden **nicht** aberkannt. Erreichtes rückwirkend
wegzunehmen, weil ein Eintrag korrigiert wurde, wäre die schlechtere
Überraschung — und lüde zum Missbrauch der Löschfunktion als Rückabwicklung
ein.

## Technische Umsetzung

- **Neu:** `data/checkin_delete_queue.dart` nach dem Muster von
  `data/venue_queue.dart` (FIFO, idempotent)
- **Geändert:** `widgets/checkin_card.dart` (Menü), `features/feed/`,
  `features/profile/diary_screen.dart`, `data/providers.dart`
  (`BrewActions.deleteCheckin`), `data/online/online_service.dart`
- **Lokal:** Drift v10 — Tabelle `checkin_delete_queue`; Löschen der
  Check-in-Zeile
- **Server:** keine Migration nötig. `checkins_delete` erlaubt bereits
  `profile_id = auth.uid()`; `toasts` und `comments` hängen mit
  `on delete cascade` daran und verschwinden mit.
- **Speicher:** Foto im Bucket `beer-photos` mitlöschen (`photo_url`)

**Reihenfolge beim Löschen:** erst lokal, dann Server, dann Foto. Bricht
der Server ab, bleibt der Auftrag in der Warteschlange; das Foto zuletzt,
weil ein verwaistes Bild harmloser ist als ein Eintrag ohne Bild.

## Modularität

- **Hängt ab von:** Check-ins (02), Datensynchronisation (16)
- **Wird gebraucht von:** nichts — reine Ergänzung
- **Ausbauen:** Menüeintrag aus `checkin_card.dart` entfernen, Provider und
  Queue-Datei löschen, Drift-Tabelle in der nächsten Migration fallen
  lassen. Keine fremde Funktion merkt es.

## Plattformen

Alle. Kein plattformgebundenes Paket beteiligt.

## Skalierung

Unkritisch: eine Zeile pro Vorgang, die Warteschlange wird beim Abgleich
geleert. Das `cascade` auf Toasts und Kommentaren erledigt Postgres.

## Umsetzungsplan

1. **Drift v10 + Warteschlange.** Tabelle `checkin_delete_queue`,
   `replayCheckinDeletes()` analog `replayVenueQueue`.
   *Prüfkriterium:* Unit-Test — Eintrag löschen, offline, Wiedergabe holt
   es nach; doppelte Wiedergabe schadet nicht.
2. **Server- und Speicherpfad.** `OnlineService.deleteCheckin(id)` inkl.
   Foto-Entfernung.
   *Prüfkriterium:* gelöschter Check-in ist über die API nicht mehr
   abrufbar, Foto ist weg.
3. **Bedienung.** Menü in `checkin_card.dart`, Rückfrage,
   „Rückgängig"-Hinweis (5 Sekunden Aufschub vor dem echten Löschen).
   *Prüfkriterium:* Widget-Test — Menü nur bei eigenen Karten;
   „Rückgängig" stellt wieder her.
4. **Abzeichen neu bewerten** (ohne Aberkennung), Statistiken aktualisieren.
   *Prüfkriterium:* Test — Löschen senkt Zähler, entzieht aber kein
   vergebenes Abzeichen.

## Offene Punkte / Ideen

- Später: Bearbeiten statt Löschen (Bewertung oder Notiz nachträglich
  ändern) — das deckt vermutlich die Hälfte der Löschwünsche ab.
