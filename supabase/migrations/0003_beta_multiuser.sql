-- BrewMates Online-Beta (v0.9): Angleichung des Schemas an die App.
-- Die App arbeitet mit Venue-Namen als Text, Koordinaten als Zahlenpaar
-- und denormalisierten Bier-Angaben je Check-in (die Bier-Datenbank lebt
-- weiterhin redaktionell auf GitHub, nicht in Postgres).

-- Profile: die App nutzt Emoji-Avatare.
alter table profiles
  add column if not exists avatar_emoji text not null default '🍺';

-- Sessions: Beacon mit Klartext-Ort und einfachen Koordinaten.
alter table sessions add column if not exists venue_name text;
alter table sessions add column if not exists latitude double precision;
alter table sessions add column if not exists longitude double precision;

-- Check-ins: Bier-Angaben denormalisiert; die FK auf die (leere)
-- Postgres-Biertabelle wird optional.
alter table checkins alter column beer_id drop not null;
alter table checkins add column if not exists beer_name text;
alter table checkins add column if not exists brewery_name text;
alter table checkins add column if not exists beer_style text;
alter table checkins add column if not exists venue_name text;
alter table checkins add column if not exists is_alcohol_free boolean not null default false;

-- Realtime für den Live-Beacon: Freunde sehen neue/beendete Sessions sofort.
do $$
begin
  alter publication supabase_realtime add table sessions;
exception when duplicate_object then null;
end $$;

-- Beta-Komfort: Freunde-Suche per Username-Präfix (RLS-konform, da die
-- profiles-Select-Policy greift).
create index if not exists profiles_username_idx on profiles (username);
