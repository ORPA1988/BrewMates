# 23 Beacon-Laufzeit

> **Status:** 🟢 fertig — Laufzeit wählbar, verlängerbar, serverseitig
> begrenzt.
> **Seit:** 0.9.14-beta · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Ein Beacon sagt „ich bin da, kommt vorbei". Wie lange das gilt, ist von Ort
und Anlass abhängig: Das schnelle Feierabendbier dauert vierzig Minuten,
der Stammtisch fünf Stunden, das Bierfest den ganzen Tag. Eine feste
Laufzeit von drei Stunden ist für beide Enden falsch — sie lädt entweder
zu spät noch jemanden ein oder wirft die Runde vorzeitig aus der Karte.

Dass die Anzeige irgendwann von selbst verschwindet, ist dabei kein
Kompromiss, sondern ein Datenschutzmerkmal: Kein Beacon bleibt aus
Versehen stundenlang stehen.

## Funktion (Nutzersicht)

- Beim Starten einer Session eine Auswahl:
  **30 min · 1 · 2 · 3 · 5 · 8 · 12 Stunden**. Vorbelegt ist die zuletzt
  gewählte Dauer, beim ersten Mal drei Stunden — der bisherige Wert, damit
  sich für niemanden etwas ändert, der nicht hinschaut.
- Der **Ein-Tap-Beacon fragt nichts** und nimmt ebenfalls die zuletzt
  gewählte Dauer. Er soll ein Tipp bleiben; eine Rückfrage würde genau das
  zerstören, wofür es ihn gibt.
- Session-Karte und Banner zeigen die verbleibende Zeit („noch 1 h 20").
- **Verlängern** über das Banner, solange die Session läuft — gerechnet
  **ab jetzt**, nicht ab dem bisherigen Ende. „Noch zwei Stunden" ist das,
  was jemand um 22 Uhr im Wirtshaus meint.
- Vorzeitig beenden geht wie bisher jederzeit.
- Läuft die Zeit ab, endet die Session automatisch und verschwindet von der
  Karte — daran ändert sich nichts, nur der Zeitpunkt ist jetzt gewählt.

## Technische Umsetzung

- **Geändert:** `features/session/start_session_screen.dart` (erweiterte
  Auswahl), `features/session/beacon_screen.dart` (gemerkte Vorgabe),
  `features/shell/app_shell.dart` (Verlängern im Banner),
  `data/providers.dart` (`extendMySession`, `clampSessionDuration`,
  `preferredSessionDurationProvider`), `core/format.dart`
  (`formatDuration`), `data/db/database.dart` (`setSessionExpiry`),
  `data/online/online_service.dart` (`updateSessionExpiry`)
- **Server:** `sessions.expires_at` existiert seit 0001 samt
  `end_expired_sessions()`, das per Cron abgelaufene Sessions schließt —
  und `upsertSession` überträgt den Wert längst. Neu ist allein die
  **Grenzprüfung** in Migration 0021.

**Korrektur an der ersten Fassung dieses Dokuments:** Dort stand, die
Laufzeit sei „fest einprogrammiert". Das stimmte nur für den
Ein-Tap-Beacon — der ausführliche Start-Bildschirm bot 1/3/6 Stunden
bereits an, und die Restzeit stand ebenfalls schon auf der Karte. Wirklich
gefehlt haben das Verlängern, die gemerkte Vorgabe und die Grenzen.

**Grenzen:** 30 Minuten bis 12 Stunden je Vorgang, geprüft in der App
(`clampSessionDuration`) **und** serverseitig. Die
`check`-Bedingung erlaubt bis zu 24 Stunden ab Start, weil wiederholtes
Verlängern ab jetzt rechnet — sie begrenzt damit die Gesamtlebensdauer
eines Beacons auf einen Tag. `not valid` gesetzt, damit historische
Sessions die Migration nicht scheitern lassen.

**Restzeit-Anzeige** ohne Timer je Karte: Der bestehende `clockProvider`
tickt bereits im Minutentakt; die Anzeige hängt sich daran.

## Modularität

- **Hängt ab von:** Sessions & Beacons (07)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Auswahl aus dem Start-Bildschirm entfernen, Vorgabewert
  serverseitig greifen lassen. Die Datenbank bleibt unverändert.

## Plattformen

Alle.

## Skalierung

Unkritisch, im Gegenteil: Kürzere Laufzeiten bedeuten weniger gleichzeitig
aktive Sessions in Kartenabfragen.

## Umsetzungsstatus

Vollständig. Abgesichert durch `test/session_duration_test.dart`
(8 Tests): Grenzen nach oben und unten, Auswahl innerhalb der Grenzen,
Beschriftung der Dauern.

## Umsetzungsplan

Erledigt.

## Offene Punkte / Ideen

- Hinweis kurz vor Ablauf („dein Beacon endet in 10 Minuten — verlängern?")
  — sinnvoll erst mit Push-Nachrichten
- Die gemerkte Vorgabe lebt derzeit nur im Speicher; über einen Neustart
  hinweg zu merken wäre der nächste kleine Schritt
