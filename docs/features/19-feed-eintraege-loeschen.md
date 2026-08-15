# 19 Feed-Einträge löschen

> **Status:** 🟢 fertig — eigene Check-ins lassen sich löschen, offline
> wie online, mit „Rückgängig".
> **Seit:** 0.9.14-beta · **Zuletzt geprüft:** 2026-08-15

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

- **Neu:** `data/checkin_delete_queue.dart` — `replayCheckinDeleteQueue`
  nach dem Muster von `data/venue_queue.dart` (FIFO, idempotent)
- **Geändert:** `widgets/checkin_card.dart` (Menü, Rückfrage,
  „Rückgängig"), `data/providers.dart` (`BrewActions.deleteCheckin` und
  `restoreCheckin`, `checkinDeleteSyncProvider`),
  `data/online/online_service.dart` (`deleteCheckinRemote`,
  `deleteCheckinPhoto`), `features/shell/app_shell.dart`
- **Lokal:** Drift v10 — Tabelle `CheckinDeleteQueue`;
  `deleteCheckinLocal` entfernt Check-in, Toasts und Kommentare in einer
  Transaktion
- **Server:** keine Migration nötig. `checkins_delete` (0001) erlaubt
  bereits `profile_id = auth.uid()`; `toasts` und `comments` hängen mit
  `on delete cascade` daran und verschwinden mit.
- **Speicher:** Foto im Bucket `beer-photos` mitlöschen — die
  Warteschlange führt `photo_url` mit, weil die Check-in-Zeile beim
  Abspielen längst weg ist

**Reihenfolge beim Löschen:** erst lokal, dann Server, dann Foto. Bricht
der Server ab, bleibt der Auftrag in der Warteschlange; das Foto zuletzt,
weil ein verwaistes Bild harmloser ist als ein Eintrag ohne Bild.

**Eigener Provider statt Anbau.** `checkinDeleteSyncProvider` läuft im
selben Takt wie der Gasthaus-Abgleich, aber unabhängig davon — die
Alternative wäre gewesen, das Abspielen in `VenueSync.sync()`
hineinzuschreiben, was den Namen zur Lüge gemacht hätte.

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

## Umsetzungsstatus

Alle vier geplanten Schritte sind erledigt. Abgesichert durch
`test/checkin_delete_test.dart` (8 Tests): FIFO-Reihenfolge,
Foto-Entfernung, Abbruch bei Verbindungsfehlern, Verwerfen fachlicher
Fehler, Rückgängig und wiederholtes Abspielen.

**Eine bekannte Enge:** Läuft der Abgleich innerhalb der wenigen Sekunden
zwischen Löschen und „Rückgängig", ist die Serverzeile bereits weg. Der
Check-in lebt dann lokal weiter und wird vom Upload-Assistenten erneut
hochgeladen — kein Datenverlust, nur ein Umweg.

## Umsetzungsplan

Erledigt. Offen bleibt nur der naheliegende Nachbau:

1. **Bearbeiten statt Löschen** (Bewertung oder Notiz nachträglich
   ändern) — deckt vermutlich die Hälfte der Löschwünsche ab und
   verhindert, dass Erinnerungen wegen eines Tippfehlers verschwinden.

## Offene Punkte / Ideen

- Mehrere Check-ins auf einmal löschen (Auswahlmodus im Tagebuch)
