-- Vertrauensstufen (Account-Levelsystem) + Audit-Log für die Datenpflege.
--
-- Stufen: 0 gesperrt (edit_lock) · 1 Neuling · 2 Stammgast (≥25 Punkte
-- oder Feature trust_level_2) · 3 Bierkenner (≥100 Punkte oder
-- trust_level_3) · 4 Moderator (Rolle) · 5 Admin (Rolle).
-- Punkte = Check-ins + 5·eigene Biere (nicht ausgeblendet)
--          + 5·eigene Gasthäuser + 2·protokollierte Bearbeitungen.
-- Overrides laufen über die bestehende user_features-Infrastruktur.

create or replace function public.account_level(uid uuid)
returns integer
language plpgsql stable security definer set search_path = public as $$
declare
  pts integer;
begin
  -- Selbst-Scope wie bei den übrigen Helfern: fremde Konten nur für Admins.
  -- Ohne JWT-Kontext (auth.uid() NULL) gibt es grundsätzlich Stufe 0.
  if uid is null or auth.uid() is null
     or (uid <> auth.uid() and not is_admin(auth.uid())) then
    return 0;
  end if;
  if exists (select 1 from user_roles
             where profile_id = uid and role = 'admin') then
    return 5;
  end if;
  if exists (select 1 from user_roles
             where profile_id = uid and role = 'moderator') then
    return 4;
  end if;
  if exists (select 1 from user_features
             where profile_id = uid and feature = 'edit_lock' and enabled) then
    return 0;
  end if;
  if exists (select 1 from user_features
             where profile_id = uid and feature = 'trust_level_3' and enabled) then
    return 3;
  end if;
  if exists (select 1 from user_features
             where profile_id = uid and feature = 'trust_level_2' and enabled) then
    return 2;
  end if;
  select (select count(*) from checkins where profile_id = uid)
       + 5 * (select count(*) from beers
              where created_by = uid and not hidden)
       + 5 * (select count(*) from venues where created_by = uid)
       + 2 * (select count(*) from edit_log
              where profile_id = uid and action = 'update')
    into pts;
  if pts >= 100 then
    return 3;
  elsif pts >= 25 then
    return 2;
  end if;
  return 1;
end $$;

-- Für die Profil-UI: Stufe + Punktestand in einem Aufruf (nur für sich selbst).
create or replace function public.my_account_level_info()
returns table (level integer, points integer)
language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  pts integer;
begin
  if uid is null then
    return;
  end if;
  select (select count(*) from checkins where profile_id = uid)
       + 5 * (select count(*) from beers
              where created_by = uid and not hidden)
       + 5 * (select count(*) from venues where created_by = uid)
       + 2 * (select count(*) from edit_log
              where profile_id = uid and action = 'update')
    into pts;
  return query select public.account_level(uid), pts;
end $$;

-- ============================================================================
-- Audit-Log: schreibt ausschließlich der Trigger (fälschungssicher).
-- ============================================================================

create table edit_log (
  id bigint generated always as identity primary key,
  entity text not null check (entity in ('beer', 'venue')),
  entity_id uuid not null,
  profile_id uuid references profiles (id) on delete set null,
                                       -- auth.uid() zum Änderungszeitpunkt
  action text not null check (action in ('insert', 'update')),
  changes jsonb not null default '{}'::jsonb, -- {"feld":{"alt":…,"neu":…}}
  created_at timestamptz not null default now()
);
create index edit_log_entity_idx on edit_log (entity, entity_id, created_at desc);
create index edit_log_profile_idx on edit_log (profile_id, action);
alter table edit_log enable row level security;
-- Lesen: alle Angemeldeten (Änderungsverlauf ist bewusst öffentlich für
-- die Community). KEINE Schreib-Policies: Insert kommt nur vom
-- SECURITY-DEFINER-Trigger.
create policy edit_log_select on edit_log for select
  using (auth.uid() is not null);

create or replace function public.log_entity_edit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_entity text := tg_argv[0];
  v_changes jsonb := '{}'::jsonb;
  v_key text;
  v_old jsonb;
  v_new jsonb;
begin
  if tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    for v_key in select jsonb_object_keys(v_new) loop
      if v_key = 'updated_at' then
        continue;
      end if;
      if v_old -> v_key is distinct from v_new -> v_key then
        v_changes := v_changes || jsonb_build_object(
          v_key,
          jsonb_build_object('alt', v_old -> v_key, 'neu', v_new -> v_key));
      end if;
    end loop;
    if v_changes = '{}'::jsonb then
      return new; -- nichts Inhaltliches geändert → kein Log-Rauschen
    end if;
  end if;
  insert into edit_log (entity, entity_id, profile_id, action, changes)
  values (v_entity, new.id, auth.uid(), lower(tg_op), v_changes);
  return new;
end $$;
revoke execute on function public.log_entity_edit() from public, anon, authenticated;

create trigger beers_edit_log after insert or update on beers
  for each row execute function public.log_entity_edit('beer');
create trigger venues_edit_log after insert or update on venues
  for each row execute function public.log_entity_edit('venue');

-- ============================================================================
-- Level-basierte Schreibrechte
-- ============================================================================

-- Biere: bisher gab es gar keine Update-Policy. Jetzt: unverifizierte
-- Community-Biere darf der Ersteller (Stufe 1) und ab Stammgast (Stufe 2)
-- jeder bearbeiten; verified bleibt clientseitig unantastbar.
create policy beers_update on beers for update
  using (not verified
     and (created_by = auth.uid() or account_level(auth.uid()) >= 2))
  with check (not verified);

-- Gasthäuser: Ersteller oder ab Stammgast; sensible Felder schützt der
-- Guard-Trigger darunter.
drop policy venues_update on venues;
create policy venues_update on venues for update
  using (created_by = auth.uid() or account_level(auth.uid()) >= 2);

create or replace function public.guard_venue_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Wartung ohne Nutzerkontext (Dashboard/Service) bleibt unangetastet.
  if auth.uid() is null then
    return new;
  end if;
  if new.verified is distinct from old.verified
     and account_level(auth.uid()) < 3 then
    raise exception
      'Verifizieren dürfen erst Bierkenner (Vertrauensstufe 3).'
      using errcode = '42501';
  end if;
  if old.verified
     and (new.name is distinct from old.name
       or new.latitude is distinct from old.latitude
       or new.longitude is distinct from old.longitude)
     and account_level(auth.uid()) < 3 then
    raise exception
      'Name/Position verifizierter Gasthäuser ändern erst Bierkenner (Stufe 3).'
      using errcode = '42501';
  end if;
  return new;
end $$;
revoke execute on function public.guard_venue_update() from public, anon, authenticated;

create trigger venues_guard before update on venues
  for each row execute function public.guard_venue_update();

-- Grants nach 0008-Konvention.
revoke execute on function public.account_level(uuid) from public, anon;
grant execute on function public.account_level(uuid) to authenticated;
revoke execute on function public.my_account_level_info() from public, anon;
grant execute on function public.my_account_level_info() to authenticated;
