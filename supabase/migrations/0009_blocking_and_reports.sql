-- Blockieren & Melden serverseitig (Roadmap Stufe B) + Härtung der
-- friendships-Policies.
--
-- Warum eine eigene blocks-Tabelle statt friendship_status 'blocked':
-- Eine Blockierung braucht eine Richtung (wer hat wen blockiert), muss auch
-- ohne bestehende Freundschaft möglich sein und darf beim Entfreunden nicht
-- verloren gehen. Der Enum-Wert 'blocked' bleibt aus Kompatibilität bestehen,
-- wird aber nicht mehr verwendet.

-- ============================================================================
-- Blockierungen
-- ============================================================================

create table blocks (
  blocker_id uuid not null references profiles (id) on delete cascade,
  blocked_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table blocks enable row level security;

-- Nur die eigene Blockliste ist sichtbar; wer MICH blockiert, bleibt unsichtbar.
create policy blocks_select on blocks for select using (blocker_id = auth.uid());
create policy blocks_insert on blocks for insert with check (blocker_id = auth.uid());
create policy blocks_delete on blocks for delete using (blocker_id = auth.uid());

-- Gerichtete Prüfung: hat `blocker` den `target` blockiert?
-- SECURITY DEFINER, weil Policies fremde blocks-Zeilen sehen müssen, die die
-- blocks-RLS (richtigerweise) verbirgt.
create or replace function public.has_blocked(blocker uuid, target uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select (blocker = auth.uid() or target = auth.uid())
     and exists (
       select 1 from blocks
       where blocker_id = blocker and blocked_id = target
     );
$$;
revoke execute on function public.has_blocked(uuid, uuid) from public, anon;
grant execute on function public.has_blocked(uuid, uuid) to authenticated;

-- Ungerichtete Prüfung: besteht zwischen a und b (egal in welcher Richtung)
-- eine Blockierung?
create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select public.has_blocked(a, b) or public.has_blocked(b, a);
$$;
revoke execute on function public.is_blocked(uuid, uuid) from public, anon;
grant execute on function public.is_blocked(uuid, uuid) to authenticated;

-- ============================================================================
-- are_friends: Blockierung beendet jede inhaltliche Sichtbarkeit
-- (Sessions, Check-ins, Abzeichen, private Profile – überall, wo Policies
-- are_friends nutzen). Zusätzlich: Die Funktion beantwortet nur noch Paare,
-- an denen der Anfragende selbst beteiligt ist – vorher konnte jeder
-- Angemeldete per RPC beliebige fremde Freundschaften abfragen.
-- ============================================================================

create or replace function are_friends(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select (a = auth.uid() or b = auth.uid())
     and not public.is_blocked(a, b)
     and exists (
       select 1 from friendships
       where status = 'accepted'
         and ((requester_id = a and addressee_id = b)
           or (requester_id = b and addressee_id = a))
     );
$$;

-- Gleiche Selbstbezug-Härtung für die übrigen RLS-Helfer.
create or replace function is_crew_member(p_crew uuid, p_profile uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select p_profile = auth.uid()
     and exists (
       select 1 from crew_members
       where crew_id = p_crew and profile_id = p_profile
     );
$$;

create or replace function is_admin(uid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select uid = auth.uid()
     and exists (
       select 1 from user_roles where profile_id = uid and role = 'admin'
     );
$$;

-- ============================================================================
-- friendships-Policies härten. Bisher konnte ein Angreifer eine Freundschaft
-- direkt mit status='accepted' einfügen oder die eigene Anfrage selbst
-- annehmen und so einseitig „befreundet" werden. Jetzt gilt:
-- * Insert: nur eigene Anfrage, nur status 'pending', nicht an/von Blockierten.
-- * Update: nur der Empfänger nimmt an; alles andere läuft über Delete.
-- ============================================================================

drop policy friendships_insert on friendships;
create policy friendships_insert on friendships for insert with check (
  requester_id = auth.uid()
  and status = 'pending'
  and not public.is_blocked(requester_id, addressee_id)
);

drop policy friendships_update on friendships;
create policy friendships_update on friendships for update
  using (addressee_id = auth.uid())
  with check (addressee_id = auth.uid() and status in ('pending', 'accepted'));

-- Profile: Wer mich blockiert hat, ist für mich unsichtbar (Suche, Anzeige).
-- Umgekehrt sehe ich Profile, die ICH blockiert habe, weiterhin – sonst
-- ließe sich die eigene Blockliste nicht mehr verwalten.
drop policy profiles_select on profiles;
create policy profiles_select on profiles for select using (
  id = auth.uid()
  or (
    (not is_private or are_friends(id, auth.uid()))
    and not public.has_blocked(id, auth.uid())
  )
);

-- ============================================================================
-- Meldungen (Reports): Nutzer melden Profile oder Inhalte; bearbeiten
-- können sie nur Admins (Admin-Bereich der App).
-- ============================================================================

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles (id) on delete cascade,
  reported_id uuid not null references profiles (id) on delete cascade,
  subject_type text not null default 'profile'
    check (subject_type in ('profile', 'checkin', 'comment', 'session')),
  subject_id uuid,
  reason text not null check (length(reason) between 3 and 2000),
  status text not null default 'open'
    check (status in ('open', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_id)
);
create index reports_open_idx on reports (status, created_at desc);
alter table reports enable row level security;

create policy reports_insert on reports for insert
  with check (reporter_id = auth.uid());
create policy reports_select on reports for select using (
  reporter_id = auth.uid() or is_admin(auth.uid())
);
create policy reports_update on reports for update
  using (is_admin(auth.uid()));
