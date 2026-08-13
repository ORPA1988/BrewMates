# BrewMates – Supabase-Backend

## 🧪 Online-Beta (v0.9) — Setup-Status

Projekt: `swlqkwlpnxwthbneblww` (EU, eu-central-1).

**✅ Erledigt (per Supabase-MCP eingespielt):**

- Migrationen `0001`–`0005` angewendet: komplettes Schema mit RLS,
  Badges-Seed, Beta-Angleichung (venue_name/Koordinaten/denormalisierte
  Check-ins, Realtime für `sessions`), **Kontomodell** (unveränderliche
  `account_no`, Auto-Profil-Trigger `handle_new_user` für alle
  Anmeldeverfahren inkl. OAuth) und Security-Härtung laut Advisor.
- Projekt-URL + anon-Key sind in `app/lib/core/supabase_config.dart`
  eingetragen (der anon-Key ist per Design öffentlich; Schutz = RLS).

**☐ Verbleibende Dashboard-Schritte (nur über die Web-Oberfläche möglich):**

1. **E-Mail-Bestätigung aus (empfohlen für die Beta)** — Authentication →
   Sign In / Providers → Email → „Confirm email" deaktivieren. (Bleibt sie
   an, funktioniert die App trotzdem und fordert zur Bestätigung auf.)
2. **Google-Login freischalten** — braucht einmalig OAuth-Zugangsdaten aus
   der [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
   „OAuth-Client-ID" vom Typ **Webanwendung** anlegen mit Redirect-URI
   `https://swlqkwlpnxwthbneblww.supabase.co/auth/v1/callback`, dann
   Client-ID + Secret im Supabase-Dashboard unter Authentication →
   Providers → Google eintragen. Zusätzlich unter Authentication →
   URL Configuration die Redirect-URL `de.brewmates.app://login-callback`
   erlauben (der Deep-Link, über den die App aus dem Browser zurückkehrt).
   Bis dahin zeigt der Google-Knopf in der App eine verständliche Meldung;
   E-Mail + Passwort funktioniert sofort.

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
hängen die Anmeldeverfahren (E-Mail, Google, später Telefon) als
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
| `migrations/0002_seed_badges.sql` | Start-Set der Abzeichen |
| `functions/notify/` | Beacon-Fan-out beim Session-Start (Push folgt in Phase 1) |

## Sicherheitsmodell (Kurzfassung)

- **RLS auf jeder Tabelle.** Clients arbeiten ausschließlich mit dem `anon`/`authenticated`-Key; die Service-Role existiert nur in Edge Functions.
- **Standort:** `sessions.location` ist für andere nur lesbar, solange die Session `active` und nicht abgelaufen ist – und nur für die gewählte Zielgruppe. Ein `pg_cron`-Job beendet abgelaufene Sessions jede Minute serverseitig.
- **Moderation:** Community-Einreichungen (Biere/Brauereien) entstehen immer mit `verified = false`; nur die Service-Role setzt `verified = true`.
