-- Challenge-Abschlüsse serverseitig validieren + Datenpflege-Leaderboard.
--
-- Schließt die dokumentierte Beta-Lücke aus 0012: Abschlüsse entstehen
-- jetzt NUR noch über die RPC complete_challenge, die die Regel gegen die
-- Online-Check-ins des Aufrufers prüft — die denormalisierten Spalten
-- (beer_name/beer_style/brewery_name/is_alcohol_free/venue_id/venue_name/
-- created_at) reichen für alle Regeltypen.

drop policy challenge_completions_insert on challenge_completions;

create or replace function public.complete_challenge(p_challenge uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  ch challenges%rowtype;
  v_type text;
  v_threshold integer;
  v_style text;
  progress integer := 0;
begin
  if uid is null then
    return false;
  end if;
  select * into ch from challenges where id = p_challenge;
  if not found then
    return false;
  end if;
  -- Abschluss zählt auch kurz nach Challenge-Ende, aber nie vor dem Start.
  if now() < ch.starts_at then
    return false;
  end if;

  v_type := ch.rule ->> 'type';
  v_threshold := (ch.rule ->> 'threshold')::integer;
  v_style := lower(coalesce(ch.rule ->> 'style', ''));
  if v_threshold is null or v_threshold < 1 then
    return false;
  end if;

  if v_type = 'checkins_count' then
    select count(*) into progress from checkins c
    where c.profile_id = uid
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'distinct_beers' then
    select count(distinct lower(coalesce(c.beer_name, ''))) into progress
    from checkins c
    where c.profile_id = uid
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'distinct_styles' then
    select count(distinct lower(coalesce(c.beer_style, ''))) into progress
    from checkins c
    where c.profile_id = uid and c.beer_style is not null
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'distinct_breweries' then
    select count(distinct lower(coalesce(c.brewery_name, ''))) into progress
    from checkins c
    where c.profile_id = uid and c.brewery_name is not null
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'alcohol_free' then
    select count(*) into progress from checkins c
    where c.profile_id = uid and c.is_alcohol_free
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'style_specific' then
    if v_style = '' then
      return false;
    end if;
    select count(distinct lower(coalesce(c.beer_name, ''))) into progress
    from checkins c
    where c.profile_id = uid
      and lower(coalesce(c.beer_style, '')) like '%' || v_style || '%'
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  elsif v_type = 'venue_checkins' then
    select count(distinct coalesce(c.venue_id::text,
                                   lower(c.venue_name))) into progress
    from checkins c
    where c.profile_id = uid
      and (c.venue_id is not null
           or coalesce(trim(c.venue_name), '') <> '')
      and c.created_at >= ch.starts_at and c.created_at < ch.ends_at;
  else
    return false; -- unbekannter Regeltyp
  end if;

  if progress < v_threshold then
    return false;
  end if;
  insert into challenge_completions (challenge_id, profile_id)
  values (p_challenge, uid)
  on conflict do nothing;
  return true;
end $$;
revoke execute on function public.complete_challenge(uuid) from public, anon;
grant execute on function public.complete_challenge(uuid) to authenticated;

-- ============================================================================
-- Datenpflege-Leaderboard: aggregierte Punkte (Formel wie account_level)
-- über alle nicht-privaten Profile. Bewusst ohne Self-Scope: reine
-- Anzeige-Aggregation ohne IDs; private Profile bleiben draußen.
-- ============================================================================

create or replace function public.contribution_leaderboard(
  p_limit integer default 20
)
returns table (username text, avatar_emoji text, points integer)
language sql stable security definer set search_path = public as $$
  select p.username,
         p.avatar_emoji,
         (
           (select count(*) from checkins c where c.profile_id = p.id)
           + 5 * (select count(*) from beers b
                  where b.created_by = p.id and not b.hidden)
           + 5 * (select count(*) from venues v where v.created_by = p.id)
           + 2 * (select count(*) from edit_log e
                  where e.profile_id = p.id and e.action = 'update')
         )::int as points
  from profiles p
  where not p.is_private
  order by points desc, p.username asc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;
revoke execute on function public.contribution_leaderboard(integer) from public, anon;
grant execute on function public.contribution_leaderboard(integer) to authenticated;
