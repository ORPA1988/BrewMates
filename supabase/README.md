# BrewMates – Supabase-Backend

Postgres-Schema, RLS-Policies und Edge Functions (siehe
[docs/03-architektur.md](../docs/03-architektur.md) und
[docs/04-datenmodell.md](../docs/04-datenmodell.md)).

## Lokal entwickeln

Voraussetzung: [Supabase CLI](https://supabase.com/docs/guides/cli) + Docker.

```bash
supabase start          # lokale Instanz (Postgres, Auth, Realtime, Studio)
supabase db reset       # wendet migrations/ + Seeds neu an
```

Die ausgegebene `API URL` und der `anon key` gehen per `--dart-define` an die
Flutter-App (siehe `../app/README.md`).

## Deployment

```bash
supabase link --project-ref <projekt-ref>
supabase db push                     # Migrationen einspielen
supabase functions deploy notify     # Beacon-Fan-out
```

Danach in der Supabase-Konsole einen **Database Webhook** anlegen:
`INSERT` auf `public.sessions` → Edge Function `notify`.

## Struktur

| Pfad | Inhalt |
|---|---|
| `migrations/0001_initial_schema.sql` | Alle Tabellen, Enums, Indizes, RLS-Policies, Auto-Ende-Job |
| `migrations/0002_seed_badges.sql` | Start-Set der Abzeichen |
| `functions/notify/` | Beacon-Fan-out beim Session-Start (Push folgt in Phase 1) |

## Sicherheitsmodell (Kurzfassung)

- **RLS auf jeder Tabelle.** Clients arbeiten ausschließlich mit dem `anon`/`authenticated`-Key; die Service-Role existiert nur in Edge Functions.
- **Standort:** `sessions.location` ist für andere nur lesbar, solange die Session `active` und nicht abgelaufen ist – und nur für die gewählte Zielgruppe. Ein `pg_cron`-Job beendet abgelaufene Sessions jede Minute serverseitig.
- **Moderation:** Community-Einreichungen (Biere/Brauereien) entstehen immer mit `verified = false`; nur die Service-Role setzt `verified = true`.
