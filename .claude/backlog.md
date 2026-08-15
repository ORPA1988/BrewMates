# Backlog

Priorisierte Fundstellen. **Kein Ersatz** für `docs/06-roadmap.md` (was wann
kommt) und `docs/12-funktionsaudit.md` (Funktionsbefund) — hier steht nur,
was technisch aufzuräumen ist.

Aufwand: S ≤ ½ Tag · M ≈ 1–2 Tage · L > 2 Tage (2–3 Entwickler, mit
KI-Unterstützung deutlich weniger).

## A — Zuerst

| # | Punkt | Aufwand | Warum |
|---|---|---|---|
| ~~A-1~~ | ~~**Feature-Branch nach `main` bringen**~~ — erledigt 15.08.2026: PR #16 gemerged (Stufe D, 0.10.0-beta+18), PR #14 als Dublette geschlossen, Migrationen `0020–0024` live, CI und Pages grün. | — | Die 17 Commits sind drin. `0025` steht bewusst aus (siehe `CLAUDE.md`). |
| ~~A-2~~ | ~~**RLS-Tests**~~ — erledigt 15.08.2026: `supabase/tests/rls_sichtbarkeit.test.sql`, 14 pgTAP-Tests gegen die Policies (Beacon je Kreis, Crew, Zähler-Invariante, Bierlaune, `tier_for`). Läuft in der CI (`supabase start` + `supabase test db`). | — | Der erste From-scratch-Aufbau hat zwei Fehler aufgedeckt, die niemand durch Lesen fand: fehlende Tabellenrechte (→ 0025) und ein wirkungsloser Spaltenentzug (→ 0026). |
| ~~A-3~~ | ~~**Migrationsstand verifizieren**~~ — erledigt 15.08.2026: live sind exakt `0001–0019`, nichts Live-Only, kein Schema-Drift. `0020–0024` stehen aus. | — | Festgeschrieben in `CLAUDE.md`. **0024 nur zeitgleich mit dem App-Update** — es entzieht `select (thirsty_until)`. |
| ~~A-4~~ | ~~**Testabdeckung messen**~~ — erledigt 15.08.2026: `flutter test --coverage` in der CI, `tools/coverage_report.dart` schreibt Wert und die zehn schwächsten Dateien in die Job-Zusammenfassung. **Ausgangswert 29,9 %** (ohne generierten Code), Untergrenze in `ci.yml` als Ratsche. | — | Die Zahl allein sagt wenig — interessant ist die Liste darunter: Die Bildschirme mit 0 % sind dieselben, die B-5 meint. |
| ~~A-5~~ | ~~**Schichtverstoß `domain/statistics.dart`**~~ — erledigt 15.08.2026: `StatsEntry` als Eingabetyp in `domain/`, `ServingStyle` nach `core/`, Abbildung in `features/stats/`. | — | `test/architecture_test.dart` prüft die Regel ab jetzt bei jedem Lauf. |
| ~~A-6~~ | ~~**Leeres `catch` in `setFriendTier` / `updateSessionExpiry`**~~ — erledigt 15.08.2026: beide geben Erfolg zurück, die Oberfläche sagt einen Fehlschlag. | — | Bewusst **keine** Queue beim Verlängern: nachgereicht würde sie eine beendete Session wiederbeleben. Begründung in `docs/features/23`. |
| ~~A-8~~ | ~~**Die übrigen leeren `catch`-Blöcke**~~ — erledigt 15.08.2026: alle zehn geben jetzt Erfolg zurück. Nutzerhandlungen (Anfrage, Blockierung, Bierlaune, Beacon beenden) melden Fehlschläge; Best-effort-Spiegelungen schweigen weiter, aber **mit begründendem Kommentar**. | — | Dazu `sessionReconcileProvider`: schließt Beacons, die serverseitig hängen blieben. Nachziehen ist beim **Beenden** gefahrlos (verringert Sichtbarkeit), beim **Verlängern** nicht — dieselbe Frage, entgegengesetzte Antwort. |
| ~~A-7~~ | ~~**`domain/badges.dart` und `domain/challenges.dart` von der Datenbank lösen**~~ — erledigt 15.08.2026: `core/checkin_facts.dart` als gemeinsamer Eingabetyp, Laden/Schreiben in `data/badge_engine.dart` und `data/challenge_engine.dart`. | — | **Die Ausnahmeliste in `test/architecture_test.dart` ist jetzt leer.** `domain/` hängt nirgends mehr an `data/`. |

## B — Danach

| # | Punkt | Aufwand | Warum |
|---|---|---|---|
| ~~B-1~~ | ~~**Trigram-Index**~~ — erledigt 15.08.2026: Migration 0027, `pg_trgm` im Schema `extensions`, GIN auf `username` und `display_name`. Live eingespielt. | — | `supabase/tests/suche_index.test.sql` prüft, dass der Planer die Indizes **wählt** — ein Index, den niemand nutzt, ist nur Schreiblast. |
| B-2 | **Cloud-Wiederherstellung inkrementell** statt „immer alles" | M | Beim Gerätewechsel wächst die Wiederherstellung sonst linear mit dem Bestand. |
| B-3 | **`online_service.dart` (1.573 Z.) entflechten** in `online/friends.dart`, `online/sessions.dart`, `online/checkins.dart`, `online/venues.dart` | M | Jede Änderung lädt heute die ganze Datei in den Kontext — direkter Token- und Fehlerkostentreiber. |
| B-4 | **`providers.dart` (939 Z.) je Feature aufteilen** | M | Gleicher Grund. Provider gehören neben ihr Feature. |
| B-5 | **Widget-Tests für die Kernbildschirme** (Home, Scan, Karte) | M | Die drei Bildschirme, über die alles läuft, sind ungetestet. |
| B-6 | **Check-ins bearbeiten** (nicht nur löschen) | M | Deckt laut Audit vermutlich die Hälfte der Löschwünsche ab. |

## C — Später / beobachten

| # | Punkt | Aufwand | Warum |
|---|---|---|---|
| C-1 | Community-DB serverseitig durchsuchbar statt acht Volldateien im Bundle | L | Erst ab ~50.000 Nutzern nötig. Vorher wäre der Umbau verfrüht. |
| C-2 | Push-Benachrichtigungen (FCM) für Session-Start, mit Spam-Bremse | M | Der virale Kern von Beer With Me. **Extern blockiert:** braucht ein Firebase-Projekt. |
| C-3 | Homescreen-Widget (`home_widget`) | M | Sichtbares Alleinstellungsmerkmal, aber kein Fundament. |
| C-4 | Crew-Feed | M | Letzte offene Lücke der Crew-Funktion. |
| C-5 | Heatmap zur Wochen-Serie | S | Nice-to-have aus der Wettbewerbsanalyse. |

## Bewusst offen (keine Aufgabe, dokumentierte Baseline)

- `spatial_ref_sys`-RLS und PostGIS im `public`-Schema: nur durch
  `supabase_admin` änderbar, betrifft öffentliche Koordinatendaten.
- Leaked-Password-Protection deaktiviert.
- `authenticated`-Grants auf den RLS-Helfern (`are_friends`, `is_admin`,
  `is_crew_member`, `count_other_active_sessions`) — Absicht.

## Bewusst NICHT gebaut

Unique-Tick-Mechaniken und Mengen-Ranglisten, Werbung im Feed,
Kontakte-Import, Spirituosen, Verified-Venue-Komplexität, öffentliche
Bewertungs-Ranglisten. Begründung in `docs/06-roadmap.md`.
