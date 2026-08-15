# 12 Challenges

> **Status:** 🟢 fertig — serverseitig validiert, Admin-Editor vorhanden.
> **Seit:** 0.9.0 (0012), Validierung 0.9.7 (0014) ·
> **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Abzeichen sind dauerhaft, Challenges sind befristet: „Stil-Safari im
August". Sie geben der App einen Grund, im laufenden Monat geöffnet zu
werden, und lassen sich ohne App-Update starten.

Wie bei den Abzeichen gilt: Ziele belohnen Vielfalt und Entdeckung, nie
Menge.

## Funktion (Nutzersicht)

- Laufende Challenges mit Zeitraum, Ziel und Fortschritt
- Beim Erreichen wird sie serverseitig geprüft und abgeschlossen
- Abgeschlossene bleiben im Profil sichtbar
- Bestenliste der Beitragenden

## Technische Umsetzung

- **Dateien:** `domain/challenges.dart`,
  `features/profile/challenges_screen.dart`,
  `features/admin/challenge_editor_screen.dart`
- **Server:** `challenges`, `challenge_completions` (0012); RPC
  `complete_challenge` und Sicht `contribution_leaderboard` (0014)
- **Sicherheit:** Direkte Einfügungen in `challenge_completions` sind
  **gesperrt**. Nur die geprüfte Funktion darf abschließen — sonst könnte
  jeder Client behaupten, fertig zu sein.

Das ist die Stelle, an der die App am deutlichsten zeigt, wie sie mit
Vertrauen umgeht: Die Oberfläche rechnet den Fortschritt vor, aber
entscheiden darf sie nicht.

## Modularität

- **Hängt ab von:** Check-ins (02), Vertrauensstufen (15) für den Editor
- **Wird gebraucht von:** nichts
- **Ausbauen:** Bildschirme und Editor entfernen; Tabellen können bleiben.

## Plattformen

Alle.

## Skalierung

Die Prüffunktion läuft je Abschluss einmal und zählt über die eigenen
Check-ins — unkritisch, solange die Zahl der Check-ins je Person
überschaubar bleibt. Die Bestenliste ist eine Sicht und sollte bei vielen
Nutzern materialisiert werden.

## Umsetzungsstatus

Vollständig. Der Editor liegt im Admin-Bereich, Challenges lassen sich
also im laufenden Betrieb anlegen.

## Umsetzungsplan

Nur Betrieb: regelmäßig neue Challenges einstellen. Später Crew-Challenges,
sobald Crews einen eigenen Bereich haben.

## Offene Punkte / Ideen

- Benachrichtigung, wenn eine Challenge endet — braucht Push
- Wiederkehrende Challenges (jeden Monat automatisch)
