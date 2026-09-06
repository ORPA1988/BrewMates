# BrewMates – Supabase-Backend

## Stand des Projekts

Projekt: `swlqkwlpnxwthbneblww` (EU, eu-central-1).

**Live sind die Migrationen `0001`–`0062`**, lückenlos. `list_migrations`
meldet 63 Einträge gegen 62 Dateien im Repo — das ist **kein Drift**:
`0024_friend_tiers.sql` wurde seinerzeit in zwei Schritten eingespielt,
inhaltlich steht beides in der einen Datei. Was am Server steht und warum,
führt [docs/13 — Migrationen & Lehren](../docs/13-migrationen-und-lehren.md);
diese Datei sagt nur, wie man damit arbeitet.

**Drei Edge Functions sind aktiv:** `notify` (Beacon- und Session-Push),
`feedback-issue` (Meldung aus der App wird ein GitHub-Issue) und
`github-sync` (Status und Antwort vom Issue zurück in die App).

**Anmeldung:** acht OAuth-Anbieter (Google, Microsoft/`azure`, Facebook,
GitHub, Discord, LinkedIn/`linkedin_oidc`, Twitch, Spotify) plus E-Mail
ohne Bestätigungspflicht. **Welche Knöpfe die App zeigt, entscheidet die
Tabelle `app_config` (Schlüssel `auth_providers`), nicht das Release** —
die Liste zu ändern ändert die Knöpfe auch auf Geräten, die nie wieder
aktualisiert werden. Apple fehlt bewusst (99 $/Jahr).

**Der Riegel** `app_config.min_supported_version` steht auf `0.10.4`.
Ihn anzuheben sperrt ältere Installationen aus und ist eine Entscheidung
für einen Menschen, nicht für eine Sitzung.

> Bis 2026-09-06 stand hier eine Einrichtungsanleitung auf dem Stand von
> Migration 0005, samt „☐ Google-Login freischalten" — erledigt seit
> Monaten. Eine Anleitung, die längst Getanes als offen führt, kostet
> beim nächsten Lauf echte Zeit.

**Rollen & Funktionen (Migration 0006):** `user_roles` (admin/moderator)
und `user_features` (premium, moderation, beta_features, …) — schreiben
dürfen ausschließlich Admins, serverseitig per RLS erzwungen (bewusst
getrennt von `profiles`, damit niemand sich selbst befördern kann). Der
erste Admin wird automatisch beim Registrieren des Projektinhaber-Kontos
(E-Mail-Abgleich im Auth-Trigger) gesetzt; weitere Admins ernennt er im
Admin-Bereich der App. Sessions bleiben dauerhaft angemeldet (persistiert
+ Auto-Refresh), bis der Nutzer sich aktiv abmeldet — auch über
App-Updates hinweg.

**Kontomodell (Stand der Technik):** Die unveränderliche Konto-Identität
ist `auth.users.id` (UUID) plus die kurze Anzeige-`account_no`. Daran
hängen die Anmeldeverfahren (E-Mail und acht OAuth-Anbieter) als
`auth.identities` — alle änderbar. Der Nutzername ist frei wählbar,
global einmalig (unique) und jederzeit änderbar (Konto-Screen der App).

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
| `migrations/0002_seed_badges.sql` | Sechs Abzeichen als Katalog-Rest. **Die App führt ihren Katalog (23 Abzeichen) in `domain/badges.dart` und liest diese Tabelle nicht** — seit 0016 hängt `user_badges` nicht mehr daran |
| `migrations/…` bis `0062` | Der weitere Aufbau, erklärt in docs/13 |
| `functions/notify/` | Push beim Session-Start und für Beacons (live seit 0.10.10) |
| `functions/feedback-issue/` | Meldung aus der App → GitHub-Issue |
| `functions/github-sync/` | Issue-Status und Antwort → zurück in die App |
| `tests/` | pgTAP-Tests gegen die RLS-Regeln, laufen in der CI |

## Sicherheitsmodell (Kurzfassung)

- **RLS auf jeder Tabelle.** Clients arbeiten ausschließlich mit dem `anon`/`authenticated`-Key; die Service-Role existiert nur in Edge Functions.
- **Standort:** `sessions.location` ist für andere nur lesbar, solange die Session `active` und nicht abgelaufen ist – und nur für die gewählte Zielgruppe. Ein `pg_cron`-Job beendet abgelaufene Sessions jede Minute serverseitig.
- **Moderation:** Community-Einreichungen (Biere/Brauereien) entstehen immer mit `verified = false`; nur die Service-Role setzt `verified = true`.
