# Konventionen

Verbindlich für jede Code-Änderung. Ergänzt `CLAUDE.md` (Projektstand) und
`docs/03-architektur.md` (Struktur). Kein Duplikat davon.

## Sprache

- Antworten an den Nutzer: **Deutsch**, technisch präzise, keine Floskeln.
- Code, Bezeichner, Kommentare, Commit-Messages: **Englisch**.
- Nutzersichtbare Texte in der App: **Deutsch** (Zielmarkt AT/DE/CH).

## Branches

- Basis ist immer `main`. Nie direkt auf `main` committen.
- Namensschema: `feat/<kurz>`, `fix/<kurz>`, `chore/<kurz>`, `docs/<kurz>`.
- Ein Branch = ein Thema. Findet sich unterwegs etwas anderes: nach
  `.claude/backlog.md`, nicht in den laufenden Commit.
- Branches nach dem Merge löschen. Länger als zwei Wochen offene Branches
  sind ein Fehler — sie verlieren den Anschluss (siehe Vorfall 08/2026:
  17 Commits ungemerged).

## Commits (Conventional Commits)

```
<typ>(<bereich>): <was, imperativ, klein, ohne Punkt>

<warum — ein bis drei Sätze, wenn nicht offensichtlich>
```

Typen: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`.
Bereiche: `scan`, `session`, `feed`, `beers`, `venues`, `friends`, `crews`,
`profile`, `sync`, `db`, `auth`, `map`, `web`, `android`.

Beispiel: `feat(friends): add QR code invitation flow`

## Versionierung

Ein Bump ändert **immer beide Stellen**, sonst schlägt der Test fehl:

1. `app/pubspec.yaml` → `version:`
2. `AppConfig.appVersion` in `app/lib/core/config.dart`

`versionCode` (die Zahl nach `+`) zählt monoton hoch und wird nie
zurückgesetzt — auch nicht bei Rücknahme eines Releases.

## Fehlerbehandlung

- Kein leeres `catch {}`. Entweder behandeln oder weiterwerfen.
- Netzwerk- und Supabase-Aufrufe: Fehler abfangen, dem Nutzer einen
  verständlichen deutschen Hinweis zeigen, lokalen Zustand nicht zerstören.
- Schreibende Aktionen sind **local-first**: erst lokal wirksam, dann
  Abgleich. Vorbild ist `venue_edit_queue` / `checkin_delete_queue`.
- Sicherheit wird **serverseitig** durchgesetzt (RLS, RPC). Die Oberfläche
  spiegelt sie nur. Eine UI-Prüfung ohne RLS-Pendant gilt als Lücke.

## Logging

- Kein `print()` im Produktivpfad. `debugPrint()` nur in `kDebugMode`.
- Nie loggen: Standortdaten, E-Mail-Adressen, Zugangstoken, Nutzernamen
  Dritter.

## Plattform-Regeln

- **Kein `dart:io` in `app/lib/`** — die CI erzwingt `flutter build web`.
  Plattform-Weichen über `kIsWeb` / `defaultTargetPlatform` bzw.
  Conditional Imports (`data/db/connection/`).
- Gepinnte Pakete (`mobile_scanner ^5.2.3`, `geolocator ^13.0.2`,
  `sqlite3.wasm`, `drift_worker.js`) nicht ohne Toolchain-Upgrade anheben.

## Definition of Done

Eine Änderung ist fertig, wenn **alle** Punkte erfüllt sind:

- [ ] `cd app && flutter analyze` ohne Befund
- [ ] `cd app && flutter test` grün, neue Logik hat einen eigenen Test
- [ ] `cd app && flutter build web --release` läuft durch (kein `dart:io`)
- [ ] Keine ungenutzten Imports, keine auskommentierten Code-Leichen
- [ ] Öffentliche Funktionen und Klassen mit `///` dokumentiert
- [ ] Bei Schemaänderung: Migration angelegt **und** Drift-Version erhöht
- [ ] Bei neuer RPC-Funktion: explizites `grant execute … to authenticated`
- [ ] Betroffenes Dokument in `docs/features/` aktualisiert
- [ ] Zusammenfassung: **was** geändert, **warum**, was bewusst **nicht**

## Testausführung

`flutter test` **nie** nach `tail` pipen (hängt scheinbar) — in eine Datei
umleiten und die Datei lesen.
