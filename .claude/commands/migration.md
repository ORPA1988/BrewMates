---
description: Supabase-Migrationsstand prüfen (Repo gegen Live-Projekt)
---

Vergleiche die Migrationen im Repo mit dem Live-Projekt
`swlqkwlpnxwthbneblww` (EU). Nutze den Supabase-MCP aus `.mcp.json`.

1. Liste `supabase/migrations/` auf allen Branches — höchste Nummer je Branch.
2. Frage über den Supabase-MCP den tatsächlich angewendeten Stand ab
   (`list_migrations` bzw. die `supabase_migrations.schema_migrations`-Tabelle).
3. Stelle beides gegenüber: **im Repo, aber nicht live** und **live, aber
   nicht im Repo**. Der zweite Fall ist der gefährlichere — sag ihn zuerst.
4. Prüfe für jede Migration, die noch nicht live ist:
   - Ist sie idempotent / wiederholbar?
   - Enthält sie für jede neue Funktion ein explizites
     `grant execute … to authenticated`?
   - Ändert sie RLS-Policies? Dann nenne ausdrücklich, wer danach was sieht.
5. Führe den Security-Advisor aus und stelle die Befunde der dokumentierten
   Baseline in `CLAUDE.md` gegenüber. Melde nur, was **neu** ist.

**Wende nichts an.** Erstelle nur den Bericht und einen Vorschlag in
welcher Reihenfolge ausgerollt würde. Ausrollen entscheide ich.

Aktualisiere danach den Abschnitt „Backend" in `CLAUDE.md` auf den
festgestellten Ist-Stand.
