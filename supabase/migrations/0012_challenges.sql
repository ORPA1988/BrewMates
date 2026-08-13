-- Challenges (Herausforderungen mit Belohnungs-Badge): Admins legen sie in
-- der App an, alle Nutzer sehen aktive Challenges; der Fortschritt wird
-- clientseitig aus den eigenen Check-ins im Zeitfenster berechnet (gleiches
-- Muster wie die lokalen Abzeichen).
--
-- Bekannte Beta-Einschränkung (bewusst): Der Abschluss wird vom Client
-- gemeldet und serverseitig NICHT erneut validiert — gleiches
-- Vertrauensmodell wie die denormalisierten Check-in-Spiegel.

create table challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(title) between 3 and 80),
  description text not null default '',
  emoji text not null default '🏆',
  -- {"type": "distinct_styles", "threshold": 5, "style": "IPA"?}
  rule jsonb not null
    check (jsonb_typeof(rule) = 'object' and rule ? 'type' and rule ? 'threshold'),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
alter table challenges enable row level security;

create policy challenges_select on challenges for select
  using (auth.uid() is not null);
create policy challenges_admin_insert on challenges for insert
  with check (is_admin(auth.uid()));
create policy challenges_admin_update on challenges for update
  using (is_admin(auth.uid()));
create policy challenges_admin_delete on challenges for delete
  using (is_admin(auth.uid()));

create table challenge_completions (
  challenge_id uuid not null references challenges (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (challenge_id, profile_id)
);
alter table challenge_completions enable row level security;

-- Selbst eintragen/zurückziehen; Freunde und Admins sehen Abschlüsse.
create policy challenge_completions_insert on challenge_completions for insert
  with check (profile_id = auth.uid());
create policy challenge_completions_select on challenge_completions for select
  using (profile_id = auth.uid()
      or are_friends(auth.uid(), profile_id)
      or is_admin(auth.uid()));
create policy challenge_completions_delete on challenge_completions for delete
  using (profile_id = auth.uid());
