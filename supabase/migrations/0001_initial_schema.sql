-- BrewMates – Initiales Schema (siehe docs/04-datenmodell.md)
-- Konventionen: UUIDs (client-generierbar für Offline-Sync), RLS überall aktiv.

create extension if not exists postgis;

-- ============================================================================
-- Enums
-- ============================================================================

create type friendship_status as enum ('pending', 'accepted', 'blocked');
create type visibility as enum ('friends', 'crew', 'private');
create type session_status as enum ('active', 'ended');
create type participant_kind as enum ('joined', 'toast');
create type serving_style as enum ('draft', 'bottle', 'can', 'growler');
create type crew_role as enum ('owner', 'member');
create type device_platform as enum ('android', 'ios', 'windows');

-- ============================================================================
-- updated_at-Automatik
-- ============================================================================

create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ============================================================================
-- Profile & Freundschaften
-- ============================================================================

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,30}$'),
  display_name text not null,
  avatar_url text,
  bio text,
  favorite_styles text[] not null default '{}',
  is_private boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_updated before update on profiles
  for each row execute function set_updated_at();

create table friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles (id) on delete cascade,
  addressee_id uuid not null references profiles (id) on delete cascade,
  status friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);
create trigger friendships_updated before update on friendships
  for each row execute function set_updated_at();
create index friendships_addressee_idx on friendships (addressee_id, status);

-- Zentrale Hilfsfunktion: wird von fast allen RLS-Policies genutzt.
create or replace function are_friends(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from friendships
    where status = 'accepted'
      and ((requester_id = a and addressee_id = b)
        or (requester_id = b and addressee_id = a))
  );
$$;

-- ============================================================================
-- Crews
-- ============================================================================

create table crews (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  emoji text,
  owner_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table crew_members (
  crew_id uuid not null references crews (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  role crew_role not null default 'member',
  created_at timestamptz not null default now(),
  primary key (crew_id, profile_id)
);

create or replace function is_crew_member(p_crew uuid, p_profile uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from crew_members
    where crew_id = p_crew and profile_id = p_profile
  );
$$;

-- ============================================================================
-- Brauereien, Biere, Venues
-- ============================================================================

create table breweries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text,
  city text,
  logo_url text,
  verified boolean not null default false,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table beers (
  id uuid primary key default gen_random_uuid(),
  brewery_id uuid not null references breweries (id) on delete cascade,
  name text not null,
  style text not null,
  abv numeric(4,1) check (abv >= 0 and abv <= 70),
  ibu integer check (ibu >= 0 and ibu <= 200),
  description text,
  label_url text,
  is_alcohol_free boolean not null default false,
  verified boolean not null default false,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

-- Volltextsuche über Name + Stil (Brauereiname wird beim Suchen gejoint).
create index beers_search_idx on beers
  using gin (to_tsvector('simple', name || ' ' || style));
create index beers_brewery_idx on beers (brewery_id);

create table venues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location geography(point, 4326),
  address text,
  osm_id text,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);
create index venues_location_idx on venues using gist (location);

-- ============================================================================
-- Sessions (Herzstück der Treffen)
-- ============================================================================

create table sessions (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references profiles (id) on delete cascade,
  venue_id uuid references venues (id) on delete set null,
  message text,
  location geography(point, 4326),           -- null bei Stealth
  visibility visibility not null default 'friends',
  crew_id uuid references crews (id) on delete set null,
  status session_status not null default 'active',
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  expires_at timestamptz not null default now() + interval '3 hours',
  check (visibility <> 'crew' or crew_id is not null)
);
create index sessions_active_idx on sessions (host_id) where status = 'active';

create table session_participants (
  session_id uuid not null references sessions (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  kind participant_kind not null,
  created_at timestamptz not null default now(),
  primary key (session_id, profile_id, kind)
);

-- Serverseitiges Auto-Ende: Standort verschwindet auch dann, wenn kein Client
-- je „Beenden" drückt. Einplanung via pg_cron (siehe Migration-Ende).
create or replace function end_expired_sessions()
returns void language sql security definer set search_path = public as $$
  update sessions
  set status = 'ended', ended_at = now()
  where status = 'active' and expires_at <= now();
$$;

-- ============================================================================
-- Check-ins (Herzstück des Tagebuchs) + Interaktion
-- ============================================================================

create table checkins (
  id uuid primary key,                        -- Client-generiert (Offline-Sync)
  profile_id uuid not null references profiles (id) on delete cascade,
  beer_id uuid not null references beers (id) on delete restrict,
  session_id uuid references sessions (id) on delete set null,
  venue_id uuid references venues (id) on delete set null,
  rating numeric(3,2) check (rating >= 0 and rating <= 5
                             and (rating * 4) = floor(rating * 4)),
  note text,
  photo_url text,
  flavor_tags text[] not null default '{}',
  serving_style serving_style,
  visibility visibility not null default 'friends',
  created_at timestamptz not null default now()
);
create index checkins_profile_idx on checkins (profile_id, created_at desc);
create index checkins_session_idx on checkins (session_id);
create index checkins_beer_idx on checkins (beer_id);

create table toasts (
  checkin_id uuid not null references checkins (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (checkin_id, profile_id)
);

create table comments (
  id uuid primary key default gen_random_uuid(),
  checkin_id uuid not null references checkins (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  body text not null check (length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index comments_checkin_idx on comments (checkin_id, created_at);

-- ============================================================================
-- Abzeichen, Wunschliste, Geräte, Benachrichtigungen
-- ============================================================================

create table badges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null,
  icon text not null,
  rule jsonb not null                -- z. B. {"type":"distinct_styles","threshold":5}
);

create table user_badges (
  profile_id uuid not null references profiles (id) on delete cascade,
  badge_id uuid not null references badges (id) on delete cascade,
  level integer not null default 1,
  awarded_at timestamptz not null default now(),
  primary key (profile_id, badge_id)
);

create table wishlist_items (
  profile_id uuid not null references profiles (id) on delete cascade,
  beer_id uuid not null references beers (id) on delete cascade,
  note text,
  created_at timestamptz not null default now(),
  primary key (profile_id, beer_id)
);

create table devices (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  platform device_platform not null,
  push_token text not null,
  last_seen_at timestamptz not null default now(),
  unique (profile_id, push_token)
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles (id) on delete cascade,
  type text not null,                -- beacon | joined | toast | comment | friend_request | badge
  actor_id uuid references profiles (id) on delete set null,
  subject_type text,
  subject_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_recipient_idx
  on notifications (recipient_id, created_at desc);

-- ============================================================================
-- Row Level Security
-- ============================================================================

alter table profiles enable row level security;
alter table friendships enable row level security;
alter table crews enable row level security;
alter table crew_members enable row level security;
alter table breweries enable row level security;
alter table beers enable row level security;
alter table venues enable row level security;
alter table sessions enable row level security;
alter table session_participants enable row level security;
alter table checkins enable row level security;
alter table toasts enable row level security;
alter table comments enable row level security;
alter table badges enable row level security;
alter table user_badges enable row level security;
alter table wishlist_items enable row level security;
alter table devices enable row level security;
alter table notifications enable row level security;

-- Profile: eigenes immer; fremde nur wenn öffentlich oder befreundet.
create policy profiles_select on profiles for select using (
  id = auth.uid() or not is_private or are_friends(id, auth.uid())
);
create policy profiles_insert on profiles for insert
  with check (id = auth.uid());
create policy profiles_update on profiles for update using (id = auth.uid());

-- Freundschaften: nur die Beteiligten.
create policy friendships_select on friendships for select using (
  requester_id = auth.uid() or addressee_id = auth.uid()
);
create policy friendships_insert on friendships for insert with check (
  requester_id = auth.uid()
);
create policy friendships_update on friendships for update using (
  addressee_id = auth.uid() or requester_id = auth.uid()
);
create policy friendships_delete on friendships for delete using (
  requester_id = auth.uid() or addressee_id = auth.uid()
);

-- Crews: nur Mitglieder sehen Crew & Mitgliederliste.
create policy crews_select on crews for select using (
  is_crew_member(id, auth.uid())
);
create policy crews_insert on crews for insert with check (owner_id = auth.uid());
create policy crews_update on crews for update using (owner_id = auth.uid());
create policy crews_delete on crews for delete using (owner_id = auth.uid());
create policy crew_members_select on crew_members for select using (
  is_crew_member(crew_id, auth.uid())
);
create policy crew_members_insert on crew_members for insert with check (
  exists (select 1 from crews where id = crew_id and owner_id = auth.uid())
  or profile_id = auth.uid()
);
create policy crew_members_delete on crew_members for delete using (
  profile_id = auth.uid()
  or exists (select 1 from crews where id = crew_id and owner_id = auth.uid())
);

-- Bier-Datenbank & Venues: für alle Angemeldeten lesbar; Einreichungen
-- landen unverifiziert (Moderation setzt verified via Service-Role).
create policy breweries_select on breweries for select using (auth.uid() is not null);
create policy breweries_insert on breweries for insert with check (
  created_by = auth.uid() and verified = false
);
create policy beers_select on beers for select using (auth.uid() is not null);
create policy beers_insert on beers for insert with check (
  created_by = auth.uid() and verified = false
);
create policy venues_select on venues for select using (auth.uid() is not null);
create policy venues_insert on venues for insert with check (auth.uid() is not null);

-- Sessions – der Kern der Standort-Privatsphäre:
-- Fremde sehen eine Session NUR solange sie aktiv & nicht abgelaufen ist,
-- und nur gemäß Sichtbarkeit. Danach ist der Standort serverseitig weg.
create policy sessions_select on sessions for select using (
  host_id = auth.uid()
  or (
    status = 'active' and expires_at > now()
    and (
      (visibility = 'friends' and are_friends(host_id, auth.uid()))
      or (visibility = 'crew' and is_crew_member(crew_id, auth.uid()))
    )
  )
);
create policy sessions_insert on sessions for insert with check (host_id = auth.uid());
create policy sessions_update on sessions for update using (host_id = auth.uid());

create policy session_participants_select on session_participants for select using (
  exists (select 1 from sessions s where s.id = session_id)  -- RLS von sessions greift
);
create policy session_participants_insert on session_participants for insert with check (
  profile_id = auth.uid()
);
create policy session_participants_delete on session_participants for delete using (
  profile_id = auth.uid()
);

-- Check-ins: Besitzer immer; sonst gemäß visibility.
create policy checkins_select on checkins for select using (
  profile_id = auth.uid()
  or (visibility = 'friends' and are_friends(profile_id, auth.uid()))
  or (visibility = 'crew' and session_id is not null and exists (
        select 1 from sessions s
        where s.id = session_id and s.crew_id is not null
          and is_crew_member(s.crew_id, auth.uid())
      ))
);
create policy checkins_insert on checkins for insert with check (profile_id = auth.uid());
create policy checkins_update on checkins for update using (profile_id = auth.uid());
create policy checkins_delete on checkins for delete using (profile_id = auth.uid());

-- Toasts & Kommentare: sichtbar/erlaubt, wenn man den Check-in sehen darf
-- (die Subquery unterliegt der checkins-RLS).
create policy toasts_select on toasts for select using (
  exists (select 1 from checkins c where c.id = checkin_id)
);
create policy toasts_insert on toasts for insert with check (
  profile_id = auth.uid()
  and exists (select 1 from checkins c where c.id = checkin_id)
);
create policy toasts_delete on toasts for delete using (profile_id = auth.uid());
create policy comments_select on comments for select using (
  exists (select 1 from checkins c where c.id = checkin_id)
);
create policy comments_insert on comments for insert with check (
  profile_id = auth.uid()
  and exists (select 1 from checkins c where c.id = checkin_id)
);
create policy comments_delete on comments for delete using (profile_id = auth.uid());

-- Abzeichen: Katalog öffentlich lesbar; Vergabe nur durch Edge Function
-- (Service-Role umgeht RLS – bewusst keine Insert-Policy für Nutzer).
create policy badges_select on badges for select using (true);
create policy user_badges_select on user_badges for select using (
  profile_id = auth.uid() or are_friends(profile_id, auth.uid())
);

-- Wunschliste, Geräte, Benachrichtigungen: strikt privat.
create policy wishlist_select on wishlist_items for select using (profile_id = auth.uid());
create policy wishlist_insert on wishlist_items for insert with check (profile_id = auth.uid());
create policy wishlist_delete on wishlist_items for delete using (profile_id = auth.uid());
create policy devices_all on devices for all using (profile_id = auth.uid())
  with check (profile_id = auth.uid());
create policy notifications_select on notifications for select using (
  recipient_id = auth.uid()
);
create policy notifications_update on notifications for update using (
  recipient_id = auth.uid()
);

-- ============================================================================
-- Auto-Ende-Job (pg_cron ist auf Supabase verfügbar; lokal ggf. aktivieren)
-- ============================================================================

create extension if not exists pg_cron;
select cron.schedule(
  'end-expired-sessions', '* * * * *',
  $$select end_expired_sessions()$$
);
