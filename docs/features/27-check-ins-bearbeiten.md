# 27 Check-ins bearbeiten

> **Status:** 🟢 fertig — Bewertung, Notiz, Tags, Gebinde, Menge und Ort
> nachträglich ändern; offlinefähig über `dirty`-Flag.
> **Seit:** 0.10.1-beta · **Zuletzt geprüft:** 2026-09-02

## Zielsetzung

Einen Eintrag im Tagebuch korrigieren, statt ihn wegzuwerfen.

Bis jetzt gab es nur Löschen (Funktion 19). Das Funktionsaudit vermutet,
dass **rund die Hälfte der Löschwünsche gar keine Löschwünsche sind** —
sondern verrutschte Sterne, ein Tippfehler in der Notiz oder ein
vergessenes Gebinde. Wer dafür löschen muss, verliert den Eintrag aus
seiner Erinnerung, obwohl er nur eine Kleinigkeit ändern wollte.

Das widerspricht dem Grundsatz der App: Das Tagebuch ist **Erinnerung**,
keine Bilanz. Eine Erinnerung wirft man nicht weg, weil ein Detail falsch
ist.

## Nutzersicht

Im eigenen Tagebuch und im Feed hat jeder **eigene** Eintrag ein
Stift-Symbol. Ein Tipp öffnet ein Blatt von unten mit:

- Bewertung (Sterne)
- Notiz
- Geschmacksnotizen
- Gebinde und Menge
- Ort

Speichern wirkt **sofort**, auch ohne Verbindung. Ist der Eintrag schon im
Konto, wird die Änderung beim nächsten Abgleich nachgereicht.

**Nicht änderbar ist das Bier selbst.** Ein anderes Bier ist ein anderer
Check-in — das wäre keine Korrektur, sondern eine Fälschung der eigenen
Geschichte. Wer sich im Bier geirrt hat, löscht und trinkt neu.

Fremde Check-ins lassen sich nicht bearbeiten. Das erzwingt der Server,
nicht die Oberfläche.

## Technische Umsetzung

- **Lokal zuerst:** Die Änderung landet sofort in Drift. Der Eintrag wird
  dabei als `dirty` markiert.
- **Abgleich:** `pendingCheckinUploadProvider` nimmt seit dieser Funktion
  nicht mehr nur Einträge auf, die der Server *noch nicht kennt*, sondern
  auch solche mit `dirty`. Der bestehende Upsert über die Client-UUID
  macht daraus eine Änderung statt einer Dublette — es brauchte also
  **keine** neue Schnittstelle.
- **Warum ein Flag und keine eigene Warteschlangen-Tabelle** (anders als
  `venue_edit_queue` und `checkin_delete_queue`): Dort muss die *Absicht*
  überleben, weil die Zeile selbst verschwindet oder mehrere Änderungen
  nacheinander anfallen. Hier ist die Zeile die Wahrheit und der Upsert
  idempotent — die letzte Fassung gewinnt, und genau das ist gewollt. Eine
  Tabelle daneben wäre doppelte Buchführung.
- **Server:** Keine Migration nötig. `checkins_update` aus 0001 erlaubt
  Änderungen genau dann, wenn `profile_id = auth.uid()`.
- **Drift v13:** `checkins.dirty` (bool, Vorgabe `false`).
- **Dateien:** `widgets/checkin_edit_sheet.dart` (dort, weil die
  Check-in-Karte es öffnet — ein Import aus `features/` würde die
  Schichtrichtung umdrehen),
  `data/providers.dart` (`editCheckin`), `data/db/database.dart`.

## Modularität

- **Hängt ab von:** Check-ins (02), Tagebuch (13)
- **Nutzt:** Gasthaus-Auswahl (05), Wunschliste nicht
- **Entfernbar?** Ja. Ohne die Funktion bleibt Löschen (19); das Flag in
  der Datenbank wäre dann totes Gewicht, aber harmlos.

## Plattformen

Android, Web und Desktop gleichermaßen — reine Flutter-Oberfläche ohne
Plattform-Weiche.

## Skalierung

Unkritisch. Eine Änderung betrifft eine Zeile; der Abgleich lädt sie im
selben Block wie neue Check-ins hoch.

## Status und Plan

Gebaut. Offen bleibt bewusst:

- **Kein Änderungsverlauf.** Wer wann was korrigiert hat, wird nicht
  festgehalten. Für ein privates Tagebuch wäre das Überwachung der
  eigenen Erinnerung.
- **Kein Bearbeiten des Fotos.** Ersetzen hieße, das alte aus dem Bucket
  zu räumen — das gehört zu Funktion 19 und nicht hierher.
