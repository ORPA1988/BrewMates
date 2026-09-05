-- 0062: Challenges, die einer Crew gehoeren.
--
-- Entwurf: docs/features/09-crews.md, docs/features/12-challenges.md
--
-- ============================================================================
-- WAS EINE CREW-CHALLENGE ANDERS MACHT
--
-- Genau eines: **wer mitzaehlt.** Die Regeln bleiben dieselben sieben
-- (`checkins_count`, `distinct_styles`, ...), der Zeitraum bleibt
-- derselbe, der Schwellwert auch. Statt der Check-ins einer Person
-- zaehlen die aller Mitglieder zusammen.
--
-- Deshalb wird die Regelauswertung hier **herausgezogen**, statt sie ein
-- zweites Mal hinzuschreiben: `challenge_progress(challenge, profile[])`
-- ist ab jetzt die eine Stelle, an der eine Challenge-Regel gerechnet
-- wird, und `complete_challenge` ruft sie mit einer einelementigen Liste.
--
-- Zwei Kopien derselben sieben Regeln waeren die naheliegende Loesung
-- gewesen und die schlechteste: Die erste Regel, die jemand nur in einer
-- der beiden aendert, faellt niemandem auf — beide Zahlen sehen
-- plausibel aus.
--
-- ============================================================================
-- SICHTBARKEIT UND WER SIE ANLEGT
--
-- Eine Crew-Challenge sieht nur, wer in der Crew ist. Angelegt wird sie
-- von Gruender oder Verwalter (`is_crew_admin`, 0061) — dieselbe Grenze
-- wie beim Umbenennen: Es betrifft den Alltag der Crew, nicht ihren
-- Bestand. Globale Challenges bleiben Sache der Admins.
-- ============================================================================

alter table public.challenges
  add column if not exists crew_id uuid references public.crews(id)
  on delete cascade;

comment on column public.challenges.crew_id is
  'Gehoert diese Challenge einer Crew? Dann zaehlen die Check-ins aller '
  'Mitglieder zusammen, und sichtbar ist sie nur fuer sie. NULL = die '
  'globale Challenge fuer alle.';

create index if not exists challenges_crew_idx
  on public.challenges (crew_id) where crew_id is not null;

grant select (crew_id), insert (crew_id), update (crew_id)
  on public.challenges to authenticated;

-- ----------------------------------------------------------------------------
-- Die Regelauswertung, einmal
-- ----------------------------------------------------------------------------

create or replace function public.challenge_progress(
  p_challenge uuid,
  p_profiles uuid[]
)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  ch challenges%rowtype;
  v_type text;
  v_style text;
  progress integer := 0;
begin
  select * into ch from challenges where id = p_challenge;
  if not found or p_profiles is null
     or array_length(p_profiles, 1) is null then
    return 0;
  end if;

  v_type := ch.rule ->> 'type';
  v_style := lower(coalesce(ch.rule ->> 'style', ''));

  if v_type = 'checkins_count' then
    select count(*) into progress from checkins c
    where c.profile_id = any(p_profiles)
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'distinct_beers' then
    select count(distinct lower(coalesce(c.beer_name, ''))) into progress
    from checkins c
    where c.profile_id = any(p_profiles)
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'distinct_styles' then
    select count(distinct lower(coalesce(c.beer_style, ''))) into progress
    from checkins c
    where c.profile_id = any(p_profiles) and c.beer_style is not null
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'distinct_breweries' then
    select count(distinct lower(coalesce(c.brewery_name, ''))) into progress
    from checkins c
    where c.profile_id = any(p_profiles) and c.brewery_name is not null
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'alcohol_free' then
    select count(*) into progress from checkins c
    where c.profile_id = any(p_profiles) and c.is_alcohol_free
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'style_specific' then
    if v_style = '' then
      return 0;
    end if;
    select count(distinct lower(coalesce(c.beer_name, ''))) into progress
    from checkins c
    where c.profile_id = any(p_profiles)
      and lower(coalesce(c.beer_style, '')) like '%' || v_style || '%'
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'venue_checkins' then
    select count(distinct coalesce(c.venue_id::text,
                                   lower(c.venue_name))) into progress
    from checkins c
    where c.profile_id = any(p_profiles)
      and (c.venue_id is not null
           or coalesce(trim(c.venue_name), '') <> '')
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  else
    return 0;
  end if;

  return progress;
end $fn$;

comment on function public.challenge_progress(uuid, uuid[]) is
  'Fortschritt einer Challenge ueber die angegebenen Profile. Die eine '
  'Stelle, an der eine Challenge-Regel gerechnet wird.';

-- Nicht fuer Clients: Wer hier beliebige Profil-Listen einsetzen
-- duerfte, koennte die Zahlen Dritter erfragen. Aufgerufen wird sie nur
-- von den beiden Funktionen darunter.
revoke execute on function public.challenge_progress(uuid, uuid[])
  from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- Abschluss: derselbe Weg, jetzt mit zwei Personenkreisen
-- ----------------------------------------------------------------------------

create or replace function public.complete_challenge(p_challenge uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $fn$
declare
  uid uuid := auth.uid();
  ch challenges%rowtype;
  v_threshold integer;
  v_profiles uuid[];
  progress integer;
begin
  if uid is null then
    return false;
  end if;
  select * into ch from challenges where id = p_challenge;
  if not found then
    return false;
  end if;
  if now() < ch.starts_at then
    return false;
  end if;

  v_threshold := (ch.rule ->> 'threshold')::integer;
  if v_threshold is null or v_threshold < 1 then
    return false;
  end if;

  if ch.crew_id is null then
    v_profiles := array[uid];
  else
    -- Eine Crew-Challenge schliesst nur ab, wer in der Crew ist.
    if not exists (select 1 from crew_members m
                    where m.crew_id = ch.crew_id and m.profile_id = uid) then
      return false;
    end if;
    select array_agg(m.profile_id) into v_profiles
      from crew_members m where m.crew_id = ch.crew_id;
  end if;

  progress := challenge_progress(p_challenge, v_profiles);
  if progress < v_threshold then
    return false;
  end if;

  insert into challenge_completions (challenge_id, profile_id)
  values (p_challenge, uid)
  on conflict do nothing;
  return true;
end $fn$;

comment on function public.complete_challenge(uuid) is
  'Schliesst eine Challenge ab, wenn die Regel erfuellt ist. Bei einer '
  'Crew-Challenge zaehlen die Check-ins aller Mitglieder — abschliessen '
  'kann sie trotzdem nur, wer in der Crew ist.';

-- ----------------------------------------------------------------------------
-- Fortschritt anzeigen: Die App kann ihn nicht selbst rechnen
-- ----------------------------------------------------------------------------

create or replace function public.crew_challenge_progress(p_challenge uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  ch challenges%rowtype;
  v_profiles uuid[];
begin
  select * into ch from challenges where id = p_challenge;
  if not found or ch.crew_id is null then
    return 0;
  end if;
  -- Nur fuer Mitglieder: Der Stand einer fremden Crew geht niemanden an.
  if not exists (select 1 from crew_members m
                  where m.crew_id = ch.crew_id
                    and m.profile_id = auth.uid()) then
    return 0;
  end if;
  select array_agg(m.profile_id) into v_profiles
    from crew_members m where m.crew_id = ch.crew_id;
  return challenge_progress(p_challenge, v_profiles);
end $fn$;

comment on function public.crew_challenge_progress(uuid) is
  'Gemeinsamer Stand einer Crew-Challenge. Die App kann ihn nicht selbst '
  'rechnen: Die Check-ins der anderen Mitglieder liegen nicht lokal.';

revoke execute on function public.crew_challenge_progress(uuid)
  from public, anon;
grant execute on function public.crew_challenge_progress(uuid)
  to authenticated;

-- ----------------------------------------------------------------------------
-- Sichtbarkeit und Anlegen
-- ----------------------------------------------------------------------------

drop policy if exists challenges_select on public.challenges;
create policy challenges_select on public.challenges for select
  using (
    (select auth.uid()) is not null
    and (crew_id is null or is_crew_member(crew_id, (select auth.uid())))
  );

drop policy if exists challenges_admin_insert on public.challenges;
drop policy if exists challenges_insert on public.challenges;
create policy challenges_insert on public.challenges for insert
  with check (
    (crew_id is null and is_admin((select auth.uid())))
    or (crew_id is not null and is_crew_admin(crew_id))
  );

drop policy if exists challenges_admin_update on public.challenges;
drop policy if exists challenges_update on public.challenges;
create policy challenges_update on public.challenges for update
  using (
    (crew_id is null and is_admin((select auth.uid())))
    or (crew_id is not null and is_crew_admin(crew_id))
  );

drop policy if exists challenges_admin_delete on public.challenges;
drop policy if exists challenges_delete on public.challenges;
create policy challenges_delete on public.challenges for delete
  using (
    (crew_id is null and is_admin((select auth.uid())))
    or (crew_id is not null and is_crew_admin(crew_id))
  );
