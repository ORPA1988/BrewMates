-- Crew-Zuordnung von Check-ins: eine Momentaufnahme, kein Rechenergebnis.
--
-- Der wichtigste Test hier ist der vierte. Er belegt genau den Grund,
-- aus dem die Zuordnung gespeichert und nicht abgeleitet wird: Ein
-- Austritt darf die Bilanz vergangener Abende nicht schrumpfen lassen.
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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'gastgeber');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'zusagerin');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'spaeter');
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'fremd');

-- Zwei Crews, in denen jeweils eine andere Person ist. Die Runde selbst
-- läuft OHNE crew_id — genau der Fall, den es bisher nicht gab.
insert into public.crews (id, name, emoji, owner_id) values
  ('c1000000-0000-0000-0000-000000000001', 'Crew A', '🍻',
   '11111111-1111-1111-1111-111111111111'),
  ('c2000000-0000-0000-0000-000000000002', 'Crew B', '🍺',
   '22222222-2222-2222-2222-222222222222'),
  ('c3000000-0000-0000-0000-000000000003', 'Crew C', '🍶',
   '33333333-3333-3333-3333-333333333333');

insert into public.crew_members (crew_id, profile_id, role) values
  ('c1000000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('c2000000-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222', 'owner'),
  ('c3000000-0000-0000-0000-000000000003',
   '33333333-3333-3333-3333-333333333333', 'owner');

insert into public.sessions
  (id, host_id, visibility, status, started_at, expires_at)
values
  ('55550000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'friends', 'active',
   now(), now() + interval '3 hours');

-- Die Zusagerin ist von Anfang an dabei.
insert into public.session_participants (session_id, profile_id, kind)
values ('55550000-0000-0000-0000-000000000001',
        '22222222-2222-2222-2222-222222222222', 'joined');

-- Erster Check-in: Gastgeber (Crew A) und Zusagerin (Crew B) sind da.
insert into public.checkins
  (id, profile_id, beer_name, session_id, visibility, created_at)
values
  ('cc000000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'Goldbräu',
   '55550000-0000-0000-0000-000000000001', 'friends', now());

select is(
  (select count(*)::int from public.checkin_crews
    where checkin_id = 'cc000000-0000-0000-0000-000000000001'),
  2,
  'Der Check-in trägt die Crews des Gastgebers und der Zusagerin'
);

select ok(
  exists (select 1 from public.checkin_crews
           where checkin_id = 'cc000000-0000-0000-0000-000000000001'
             and crew_id = 'c2000000-0000-0000-0000-000000000002'),
  'Auch die Crew der Zusagerin zählt — nicht nur die des Gastgebers'
);

-- Jemand sagt später zu, nachdem schon eingecheckt wurde.
insert into public.session_participants (session_id, profile_id, kind)
values ('55550000-0000-0000-0000-000000000001',
        '33333333-3333-3333-3333-333333333333', 'joined');

select is(
  (select count(*)::int from public.checkin_crews
    where checkin_id = 'cc000000-0000-0000-0000-000000000001'),
  3,
  'Eine spätere Zusage trägt ihre Crew nach — sonst hinge die Zuordnung '
  'an der Reihenfolge des Abends'
);

-- ============================================================================
-- Der Fall, der den Ausschlag gab.
-- ============================================================================

delete from public.crew_members
 where crew_id = 'c2000000-0000-0000-0000-000000000002'
   and profile_id = '22222222-2222-2222-2222-222222222222';

select is(
  (select count(*)::int from public.checkin_crews
    where checkin_id = 'cc000000-0000-0000-0000-000000000001'),
  3,
  'Ein Austritt ändert nichts: Der Abend hat stattgefunden, und die '
  'Bilanz einer Crew schrumpft nicht rückwirkend'
);

-- ============================================================================
-- Grenzen
-- ============================================================================

insert into public.checkins
  (id, profile_id, beer_name, visibility, created_at)
values
  ('cc000000-0000-0000-0000-000000000009',
   '11111111-1111-1111-1111-111111111111', 'Zwickl', 'friends', now());

select is(
  (select count(*)::int from public.checkin_crews
    where checkin_id = 'cc000000-0000-0000-0000-000000000009'),
  0,
  'Ein Check-in ohne Runde bekommt keine Crew-Zuordnung'
);

-- ============================================================================
-- Sichtbarkeit und Schreibschutz — als angemeldeter Fremder.
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

select is(
  (select count(*)::int from public.checkin_crews),
  0,
  'Wer den Check-in nicht sehen darf, sieht auch seine Crew-Zuordnung '
  'nicht'
);

select throws_ok(
  $$insert into public.checkin_crews (checkin_id, crew_id)
    values ('cc000000-0000-0000-0000-000000000001',
            'c1000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'Niemand kann die Zuordnung selbst schreiben — nur der Trigger'
);

-- Und als Beteiligter sieht man sie.
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  (select count(*)::int from public.checkin_crews
    where checkin_id = 'cc000000-0000-0000-0000-000000000001'),
  3,
  'Der Gastgeber sieht die Zuordnung seines eigenen Check-ins'
);

select * from finish();
rollback;
