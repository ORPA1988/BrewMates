# Backlog

Priorisierte Fundstellen. **Kein Ersatz** für `docs/06-roadmap.md` (was wann
kommt) und `docs/12-funktionsaudit.md` (Funktionsbefund) — hier steht nur,
was technisch aufzuräumen ist.

Aufwand: S ≤ ½ Tag · M ≈ 1–2 Tage · L > 2 Tage (2–3 Entwickler, mit
KI-Unterstützung deutlich weniger).

## A — Zuerst

| # | Punkt | Aufwand | Warum |
|---|---|---|---|
| A-1 | **Feature-Branch nach `main` bringen** und Altbranches löschen | S | Am 15.08.2026 lagen 17 Commits (+10.451 Z.) ungemerged neben `main`. Solange das offen ist, weiß niemand, was der Stand ist. |
| A-2 | **RLS-Tests** für Standort-, Freundeskreis- und Crew-Sichtbarkeit | M | Die gesamte Privatsphäre hängt an RLS. Getestet ist davon derzeit nichts. Größte Risikolücke. |
| A-3 | **Migrationsstand verifizieren** (0019–0024 live vs. nur im Repo) und den Ist-Stand in `CLAUDE.md` festschreiben | S | Ein Repo-Stand, der nicht dem Server entspricht, produziert Fehler, die niemand reproduzieren kann. |
| A-4 | **Testabdeckung messen** — `flutter test --coverage` in der CI, Wert im PR sichtbar | S | Ohne Zahl bleibt Abdeckung Gefühlssache. Aktuell ~1.675 Testzeilen gegen ~14.600 Produktivzeilen. |

## B — Danach

| # | Punkt | Aufwand | Warum |
|---|---|---|---|
| B-1 | **Trigram-Index** (`pg_trgm` + GIN) für die Freundessuche über `display_name` | S | `ilike '%x%'` kann keinen normalen Index nutzen. Ab ~5.000 Profilen spürbar. Bekannt aus dem Audit. |
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
