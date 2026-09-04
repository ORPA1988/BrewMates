-- Check-ins in einer Runde: Wer sieht sie, und wer ausdrücklich nicht?
--
-- 0050 öffnet die Sichtbarkeit über die Freundschaft hinaus — auf die
-- Leute, die am selben Tisch saßen. Jede Ausweitung einer
-- Sichtbarkeitsregel braucht den Gegenbeweis mit: Der Test zeigt nicht
-- nur, wer neu sehen darf, sondern vor allem, wer weiterhin **nicht**
-- darf.
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

begin;
select plan(8);

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

-- alice ist die Betrachterin und hat zugesagt. Mit niemandem befreundet:
-- Was sie sieht, sieht sie allein wegen der Runde.
select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'alice');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'gastgeber');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'prostende');
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'absagerin');
select pg_temp.mkuser('55555555-5555-5555-5555-555555555555', 'fremd');

insert into public.sessions
  (id, host_id, visibility, status, started_at, expires_at)
values
  ('55550000-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'friends', 'active',
   now(), now() + interval '3 hours');

-- Drei verschiedene Antworten auf dieselbe Runde. Nur eine ist eine
-- Teilnahme.
insert into public.session_participants (session_id, profile_id, kind)
values
  ('55550000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'joined'),
  ('55550000-0000-0000-0000-000000000001',
   '33333333-3333-3333-3333-333333333333', 'toast'),
  ('55550000-0000-0000-0000-000000000001',
   '44444444-4444-4444-4444-444444444444', 'declined');

-- Der Check-in des Gastgebers in seiner Runde.
insert into public.checkins
  (id, profile_id, beer_name, session_id, visibility, created_at)
values
  ('cc000000-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222',
   'Goldbräu',
   '55550000-0000-0000-0000-000000000001', 'friends', now());

-- Ein privater Check-in in derselben Runde.
insert into public.checkins
  (id, profile_id, beer_name, session_id, visibility, created_at)
values
  ('cc000000-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222',
   'Goldbräu',
   '55550000-0000-0000-0000-000000000001', 'private', now());

-- Und einer ohne Runde, der weiter allein an der Freundschaft hängt.
insert into public.checkins
  (id, profile_id, beer_name, visibility, created_at)
values
  ('cc000000-0000-0000-0000-000000000003',
   '22222222-2222-2222-2222-222222222222',
   'Goldbräu', 'friends', now());

-- alices eigener Check-in in der Runde — der Gastgeber soll ihn sehen.
insert into public.checkins
  (id, profile_id, beer_name, session_id, visibility, created_at)
values
  ('cc000000-0000-0000-0000-000000000004',
   '11111111-1111-1111-1111-111111111111',
   'Goldbräu',
   '55550000-0000-0000-0000-000000000001', 'friends', now());

-- ============================================================================
-- Als alice: hat zugesagt, ist mit niemandem befreundet.
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  (select count(*)::int from public.checkins
    where id = 'cc000000-0000-0000-0000-000000000001'),
  1,
  'Wer zugesagt hat, sieht die Check-ins der Runde — ohne Freundschaft'
);

select is(
  (select count(*)::int from public.checkins
    where id = 'cc000000-0000-0000-0000-000000000002'),
  0,
  'Ein privater Check-in bleibt privat, auch am selben Tisch'
);

select is(
  (select count(*)::int from public.checkins
    where id = 'cc000000-0000-0000-0000-000000000003'),
  0,
  'Ein Check-in ohne Runde hängt weiter allein an der Freundschaft'
);

-- ============================================================================
-- Als Gastgeber: steht nicht in session_participants, muss aber sehen.
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is(
  (select count(*)::int from public.checkins
    where id = 'cc000000-0000-0000-0000-000000000004'),
  1,
  'Der Gastgeber sieht die Check-ins seiner Runde — er sagt sich selbst '
  'nicht zu, deshalb prüft die Regel beides'
);

-- ============================================================================
-- Als Prostende: eine Geste, keine Teilnahme.
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select is(
  (select count(*)::int from public.checkins
    where id = 'cc000000-0000-0000-0000-000000000001'),
  0,
  'Zuprosten ist keine Teilnahme und öffnet nichts'
);

-- ============================================================================
-- Als Absagerin: „ich schaff's nicht" heißt, nicht dabei gewesen zu sein.
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

select is(
  (select count(*)::int from public.checkins
    where id = 'cc000000-0000-0000-0000-000000000001'),
  0,
  'Wer abgesagt hat, war nicht dabei und sieht nichts'
);

-- ============================================================================
-- Als Fremder: weder Freund noch eingeladen.
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}';

select is(
  (select count(*)::int from public.checkins
    where id = 'cc000000-0000-0000-0000-000000000001'),
  0,
  'Ein Unbeteiligter sieht die Runde nicht'
);

select is(
  (select count(*)::int from public.checkins),
  0,
  'Und auch sonst nichts — die Ausweitung gilt nur der Runde'
);

select * from finish();
rollback;
