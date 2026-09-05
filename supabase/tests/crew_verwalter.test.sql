-- 0059/0060: Was darf ein Verwalter, was bleibt beim Gründer?
--
-- Geprüft wird in der Rolle, die es betrifft. Die interessanten Fälle
-- sind die Grenzen: Ein Verwalter, der die Crew auflösen oder den
-- Gründer entfernen könnte, wäre kein Verwalter, sondern ein zweiter
-- Besitzer.
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

begin;
select plan(10);

create or replace function pg_temp.mkuser(p_id uuid, p_name text)
returns void language plpgsql as $$
begin
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, created_at, updated_at)
  values (p_id, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', p_name || '@test.invalid', '', now(), now());
  update public.profiles set username = p_name, display_name = p_name
   where id = p_id;
end $$;

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'gruender');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'verwalter');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'mitglied');

insert into public.crews (id, name, emoji, owner_id)
values ('cccccccc-0000-0000-0000-000000000001', 'Testcrew', '🍻',
        '11111111-1111-1111-1111-111111111111');

insert into public.crew_members (crew_id, profile_id, role) values
  ('cccccccc-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('cccccccc-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'admin'),
  ('cccccccc-0000-0000-0000-000000000001',
   '33333333-3333-3333-3333-333333333333', 'member');

-- ============================================================================
-- Der Helfer
-- ============================================================================

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select ok(is_crew_admin('cccccccc-0000-0000-0000-000000000001'),
          'der Verwalter gilt als Verwalter');

set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select ok(is_crew_admin('cccccccc-0000-0000-0000-000000000001'),
          'der Gruender ebenfalls — ohne eigene Rollenzeile zu brauchen');

set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
select ok(not is_crew_admin('cccccccc-0000-0000-0000-000000000001'),
          'ein einfaches Mitglied nicht');

-- ============================================================================
-- Was der Verwalter darf
-- ============================================================================

set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

update public.crews set name = 'Umbenannt'
 where id = 'cccccccc-0000-0000-0000-000000000001';
select is(
  (select name from public.crews
    where id = 'cccccccc-0000-0000-0000-000000000001'),
  'Umbenannt',
  'der Verwalter darf umbenennen');

delete from public.crew_members
 where crew_id = 'cccccccc-0000-0000-0000-000000000001'
   and profile_id = '33333333-3333-3333-3333-333333333333';
select is(
  (select count(*)::int from public.crew_members
    where crew_id = 'cccccccc-0000-0000-0000-000000000001'),
  2,
  'und ein Mitglied entfernen');

-- ============================================================================
-- Was er nicht darf
-- ============================================================================

delete from public.crew_members
 where crew_id = 'cccccccc-0000-0000-0000-000000000001'
   and profile_id = '11111111-1111-1111-1111-111111111111';
select is(
  (select count(*)::int from public.crew_members
    where crew_id = 'cccccccc-0000-0000-0000-000000000001'
      and profile_id = '11111111-1111-1111-1111-111111111111'),
  1,
  'den Gruender entfernt er nicht');

delete from public.crews where id = 'cccccccc-0000-0000-0000-000000000001';
select is(
  (select count(*)::int from public.crews
    where id = 'cccccccc-0000-0000-0000-000000000001'),
  1,
  'und die Crew loest er nicht auf');

update public.crew_members set role = 'admin'
 where crew_id = 'cccccccc-0000-0000-0000-000000000001'
   and profile_id = '22222222-2222-2222-2222-222222222222';
select is(
  (select count(*)::int from public.crew_members
    where crew_id = 'cccccccc-0000-0000-0000-000000000001'
      and role = 'admin'),
  1,
  'Rollen vergibt er nicht — auch nicht an sich selbst noch einmal');

-- ============================================================================
-- Was nur der Gruender darf
-- ============================================================================

set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

update public.crew_members set role = 'admin'
 where crew_id = 'cccccccc-0000-0000-0000-000000000001'
   and profile_id = '22222222-2222-2222-2222-222222222222';
select is(
  (select role::text from public.crew_members
    where crew_id = 'cccccccc-0000-0000-0000-000000000001'
      and profile_id = '22222222-2222-2222-2222-222222222222'),
  'admin',
  'der Gruender vergibt Rollen');

-- Und `owner` laesst sich nicht per Update verteilen: Wem die Crew
-- gehoert, steht in crews.owner_id und nirgends sonst.
select throws_ok($$
  update public.crew_members set role = 'owner'
   where crew_id = 'cccccccc-0000-0000-0000-000000000001'
     and profile_id = '22222222-2222-2222-2222-222222222222'
$$, '42501', null,
   'aber nicht die Rolle owner');

select * from finish();
rollback;
