-- 0062: Challenges, die einer Crew gehören.
--
-- Die Frage, auf die es ankommt: Zählen wirklich **alle** Mitglieder —
-- und sieht die Challenge trotzdem nur, wer dazugehört?
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

begin;
select plan(9);

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
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'mitglied');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'aussenstehend');

insert into public.crews (id, name, emoji, owner_id)
values ('cccccccc-0000-0000-0000-000000000001', 'Testcrew', '🍻',
        '11111111-1111-1111-1111-111111111111');

insert into public.crew_members (crew_id, profile_id, role) values
  ('cccccccc-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('cccccccc-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'member');

-- Eine Crew-Challenge: drei verschiedene Biere, gemeinsam.
insert into public.challenges
  (id, title, description, emoji, rule, starts_at, ends_at, crew_id)
values ('dddddddd-0000-0000-0000-000000000001', 'Gemeinsam drei', 'Test',
        '🍺', '{"type":"distinct_beers","threshold":3}'::jsonb,
        now() - interval '1 day', now() + interval '30 day',
        'cccccccc-0000-0000-0000-000000000001');

-- Zwei Biere vom Gründer, eines vom Mitglied: zusammen drei.
insert into public.checkins
  (id, profile_id, beer_name, visibility, created_at) values
  ('ee000000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'Bier A', 'friends', now()),
  ('ee000000-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111', 'Bier B', 'friends', now()),
  ('ee000000-0000-0000-0000-000000000003',
   '22222222-2222-2222-2222-222222222222', 'Bier C', 'friends', now());

-- ============================================================================
-- Wer sie sieht
-- ============================================================================

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is(
  (select count(*)::int from public.challenges
    where id = 'dddddddd-0000-0000-0000-000000000001'),
  1,
  'ein Mitglied sieht die Crew-Challenge');

set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select is(
  (select count(*)::int from public.challenges
    where id = 'dddddddd-0000-0000-0000-000000000001'),
  0,
  'ein Aussenstehender nicht');

select is(
  (select crew_challenge_progress('dddddddd-0000-0000-0000-000000000001')),
  0,
  'und erfaehrt auch den Stand nicht');

-- ============================================================================
-- Der gemeinsame Fortschritt
-- ============================================================================

set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is(
  (select crew_challenge_progress('dddddddd-0000-0000-0000-000000000001')),
  3,
  'die Check-ins aller Mitglieder zaehlen zusammen');

-- Das Mitglied allein haette nur eines — genau darum geht es.
select ok(
  (select count(*)::int from public.checkins
    where profile_id = '22222222-2222-2222-2222-222222222222') = 1,
  'obwohl es allein nur eines beigetragen hat');

-- ============================================================================
-- Abschliessen
-- ============================================================================

select ok(
  complete_challenge('dddddddd-0000-0000-0000-000000000001'),
  'ein Mitglied darf die gemeinsame Challenge abschliessen');

set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select ok(
  not complete_challenge('dddddddd-0000-0000-0000-000000000001'),
  'ein Aussenstehender nicht — auch wenn die Crew das Ziel erreicht hat');

-- ============================================================================
-- Die globale Challenge bleibt, wie sie war
-- ============================================================================

reset role;
insert into public.challenges
  (id, title, description, emoji, rule, starts_at, ends_at)
values ('dddddddd-0000-0000-0000-000000000002', 'Allein drei', 'Test',
        '🍺', '{"type":"distinct_beers","threshold":3}'::jsonb,
        now() - interval '1 day', now() + interval '30 day');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select ok(
  not complete_challenge('dddddddd-0000-0000-0000-000000000002'),
  'ohne crew_id zaehlen weiterhin nur die eigenen Check-ins');

set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- Der Gruender hat zwei eigene — auch zu wenig. Die Regel ist also
-- wirklich unveraendert und nicht versehentlich auf die Crew erweitert.
select ok(
  not complete_challenge('dddddddd-0000-0000-0000-000000000002'),
  'auch fuer den Gruender mit zwei eigenen Bieren');

select * from finish();
rollback;
