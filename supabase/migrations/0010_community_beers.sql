-- Community-Biere direkt in der Datenbank (Roadmap Stufe B/C):
-- Nutzer fotografieren Bier + EAN und legen den Eintrag sofort in der
-- Supabase-beers-Tabelle an (unverifiziert). Die Community validiert:
-- * „Loggen" = Check-in auf das Bier (Konsummeldung).
-- * „Kein Bier" = Meldung über beer_flags (eine Stimme pro Nutzer).
-- Übersteigen die „Kein Bier"-Meldungen die geloggten Konsummeldungen um
-- mindestens 10, verschwindet der Eintrag: hart gelöscht, solange keine
-- Check-ins darauf zeigen, sonst ausgeblendet (hidden), weil checkins die
-- Bier-Zeile mit ON DELETE RESTRICT referenzieren.

-- ============================================================================
-- Schema-Erweiterungen
-- ============================================================================

alter table beers add column if not exists barcode text unique
  check (barcode is null or barcode ~ '^[0-9]{8}$' or barcode ~ '^[0-9]{13}$');
alter table beers add column if not exists hidden boolean not null default false;

-- Brauereien idempotent per Name anlegbar (App: „upsert per Name").
create unique index if not exists breweries_name_key on breweries (lower(name));

-- Ausgeblendete Biere verschwinden für alle außer Admins.
drop policy beers_select on beers;
create policy beers_select on beers for select using (
  auth.uid() is not null and (not hidden or is_admin(auth.uid()))
);

-- ============================================================================
-- „Kein Bier"-Meldungen
-- ============================================================================

create table beer_flags (
  beer_id uuid not null references beers (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (beer_id, profile_id)
);
alter table beer_flags enable row level security;

-- Nur unverifizierte Community-Einträge sind meldbar; redaktionell
-- geprüfte Biere schützt die Policy.
create policy beer_flags_insert on beer_flags for insert with check (
  profile_id = auth.uid()
  and exists (select 1 from beers b where b.id = beer_id and not b.verified)
);
create policy beer_flags_select on beer_flags for select using (
  profile_id = auth.uid()
);
create policy beer_flags_delete on beer_flags for delete using (
  profile_id = auth.uid()
);

-- Prüfregel nach jeder Meldung. SECURITY DEFINER: zählt über alle
-- Check-ins hinweg (die checkins-RLS verbirgt fremde Einträge), gibt aber
-- nichts davon preis. Konsummeldungen zählen per beer_id ODER per
-- Namens-Übereinstimmung, weil die App Check-ins denormalisiert spiegelt.
create or replace function public.review_flagged_beer()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_beer beers%rowtype;
  v_brewery_name text;
  flag_count integer;
  log_count integer;
begin
  select * into v_beer from beers where id = new.beer_id;
  if not found or v_beer.verified then
    return new;
  end if;
  select name into v_brewery_name from breweries where id = v_beer.brewery_id;

  select count(*) into flag_count from beer_flags where beer_id = new.beer_id;
  select count(*) into log_count
  from checkins c
  where c.beer_id = new.beer_id
     or (lower(c.beer_name) = lower(v_beer.name)
         and lower(coalesce(c.brewery_name, '')) =
             lower(coalesce(v_brewery_name, '')));

  if flag_count >= log_count + 10 then
    if log_count = 0 then
      delete from beers where id = new.beer_id;
    else
      update beers set hidden = true where id = new.beer_id;
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.review_flagged_beer() from public, anon, authenticated;

create trigger beer_flags_review after insert on beer_flags
  for each row execute function public.review_flagged_beer();

-- Meldung per Barcode (die App kennt die Postgres-UUID oft nicht):
-- true = Meldung gezählt, false = Bier unbekannt/verifiziert/schon gemeldet.
create or replace function public.flag_beer_by_barcode(p_barcode text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_beer_id uuid;
begin
  if auth.uid() is null then
    return false;
  end if;
  select id into v_beer_id
  from beers where barcode = p_barcode and not verified and not hidden;
  if v_beer_id is null then
    return false;
  end if;
  insert into beer_flags (beer_id, profile_id)
  values (v_beer_id, auth.uid())
  on conflict do nothing;
  return found;
end $$;
revoke execute on function public.flag_beer_by_barcode(text) from public, anon;
grant execute on function public.flag_beer_by_barcode(text) to authenticated;

-- ============================================================================
-- Aggregierte echte Community-Bewertungen (Roadmap Stufe B)
-- ============================================================================

-- Nur Aggregat (Schnitt + Anzahl) über ALLE Nutzer – bewusst per
-- SECURITY DEFINER an der checkins-RLS vorbei, ohne Identitäten oder
-- Einzelwerte preiszugeben. Matching per Name+Brauerei, damit auch die
-- redaktionellen GitHub-Biere (ohne Postgres-UUID) abgedeckt sind.
create or replace function public.beer_rating_stats(
  p_beer_name text,
  p_brewery_name text
)
returns table (rating_avg numeric, rating_count integer)
language sql stable security definer set search_path = public as $$
  select round(avg(c.rating), 2) as rating_avg,
         count(c.rating)::int as rating_count
  from checkins c
  where c.rating is not null
    and lower(c.beer_name) = lower(p_beer_name)
    and (p_brewery_name is null
         or lower(coalesce(c.brewery_name, '')) = lower(p_brewery_name));
$$;
revoke execute on function public.beer_rating_stats(text, text) from public, anon;
grant execute on function public.beer_rating_stats(text, text) to authenticated;

-- ============================================================================
-- Foto-Upload: öffentlicher Bucket für Bier-/Etikettenfotos.
-- Lesen darf jeder (die Bilder sind Teil der gemeinsamen Bier-DB),
-- schreiben nur Angemeldete in einen Ordner mit ihrer eigenen User-ID.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('beer-photos', 'beer-photos', true)
on conflict (id) do nothing;

create policy "beer_photos_read" on storage.objects for select
  using (bucket_id = 'beer-photos');
create policy "beer_photos_insert" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'beer-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
