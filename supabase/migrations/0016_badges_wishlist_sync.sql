-- 0016: Cloud-Sync für Erfolge (Badges) und Wunschliste.
--
-- Die 0001-Tabellen user_badges (FK auf den badges-Katalog) und
-- wishlist_items (FK auf beers-UUIDs) waren nie in Benutzung und passen
-- nicht zum Client: Badges sind slug-basiert (inkl. dynamischer
-- challenge-<id8>-Slugs), Wunschlisten-Einträge referenzieren lokale
-- Bier-IDs (Community-IDs wie "at-001" ODER UUIDs). Beide Tabellen werden
-- daher client-kompatibel neu aufgesetzt; der badges-Katalog bleibt
-- unangetastet liegen.
--
-- Keine Funktions-Grants nötig (reine Tabellen, RLS regelt den Zugriff).

drop table if exists public.user_badges;
create table public.user_badges (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  badge_slug text not null check (char_length(badge_slug) between 1 and 80),
  awarded_at timestamptz not null default now(),
  primary key (profile_id, badge_slug)
);
alter table public.user_badges enable row level security;

-- Sichtbar für einen selbst und bestätigte Freunde (Profilansicht später).
create policy user_badges_select on public.user_badges
  for select using (
    profile_id = auth.uid() or public.are_friends(profile_id, auth.uid())
  );
create policy user_badges_insert on public.user_badges
  for insert with check (profile_id = auth.uid());
create policy user_badges_delete on public.user_badges
  for delete using (profile_id = auth.uid());

drop table if exists public.wishlist_items;
create table public.wishlist_items (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  beer_key text not null check (char_length(beer_key) between 1 and 80),
  created_at timestamptz not null default now(),
  primary key (profile_id, beer_key)
);
alter table public.wishlist_items enable row level security;

create policy wishlist_select on public.wishlist_items
  for select using (profile_id = auth.uid());
create policy wishlist_insert on public.wishlist_items
  for insert with check (profile_id = auth.uid());
create policy wishlist_delete on public.wishlist_items
  for delete using (profile_id = auth.uid());
