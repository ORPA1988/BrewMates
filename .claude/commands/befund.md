---
description: Statusbericht — wo steht das Projekt gerade?
---

Erstelle einen Kurzbefund zum aktuellen Projektstand. Nur lesen, nichts ändern.

Prüfe:

1. `git fetch --all --prune`, dann alle Remote-Branches mit Datum, Version
   und Abstand zu `main` (`git log --oneline origin/main..<branch>`).
   **Nenne ausdrücklich jeden Branch, der vor `main` liegt.**
2. Arbeitsverzeichnis sauber? Offene PRs (`gh pr list`)?
3. Letzte CI-Läufe (`gh run list --limit 5`) — rot oder grün?
4. Version in `app/pubspec.yaml` gegen `AppConfig.appVersion` in
   `app/lib/core/config.dart` — stimmen sie überein?
5. Höchste Migration in `supabase/migrations/` gegen den Stand, der in
   `CLAUDE.md` als live dokumentiert ist.
6. Offene Punkte aus `.claude/backlog.md`, Abschnitt A.

Antworte auf Deutsch, maximal eine Seite, als Tabelle plus drei Sätze
Einschätzung. Wenn etwas auseinanderläuft, sag es zuerst und deutlich.
