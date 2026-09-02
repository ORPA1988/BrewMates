-- Feedback, Roadmap und Teilnehmer-Benachrichtigungen (Migration 0037).
begin;
select plan(9);

create or replace function pg_temp.mkuser(p_id uuid, p_name text)
returns void language plpgsql as $$
begin
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, created_at, updated_at)
  values (p_id, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', p_name || '@test.invalid', '', now(), now());
end $$;
select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'anna');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'bert');

-- Roadmap: ohne Anmeldung lesbar (Testphase, Laien).
set local role anon;
select ok(
  (select count(*) from public.roadmap_items) > 0,
  'Die Roadmap ist ohne Anmeldung lesbar'
);
select throws_ok(
  $$ insert into public.roadmap_items (title, summary) values ('x', 'y') $$,
  '42501',
  null,
  'anon kann die Roadmap nicht schreiben'
);
reset role;

-- Feedback: Anna meldet, Bert sieht es nicht.
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
insert into public.feedback (profile_id, kind, body, app_version, platform)
values ('11111111-1111-1111-1111-111111111111', 'bug', 'Prost tut nichts', '0.10.8', 'android');
select is((select count(*) from public.feedback), 1::bigint,
  'Der Absender sieht seine Meldung');
select throws_ok(
  $$ insert into public.feedback (profile_id, kind, body)
     values ('11111111-1111-1111-1111-111111111111', 'wish', 'x') $$,
  null, null, 'Zu kurzer Text wird abgelehnt (Check-Constraint)'
);
-- Kein Fehler, sondern 0 Zeilen: RLS filtert die Update-Menge. Deshalb
-- wird der Zustand geprueft, nicht eine Exception erwartet.
update public.feedback set status = 'done';
select is((select status::text from public.feedback limit 1), 'open',
  'Der Absender kann den Status nicht selbst setzen');

set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
select is((select count(*) from public.feedback), 0::bigint,
  'Andere Tester sehen fremde Meldungen nicht');

-- Teilnehmer-Benachrichtigung: Bert prostet Annas Session zu.
reset role;
insert into public.sessions (id, host_id, visibility, status, started_at, expires_at)
values ('50000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111', 'friends', 'active',
        now(), now() + interval '2 hours');
insert into public.friendships (requester_id, addressee_id, status)
values ('22222222-2222-2222-2222-222222222222',
        '11111111-1111-1111-1111-111111111111', 'accepted');
delete from public.notifications; -- Anfrage-/Annahme-Zeilen aus dem Setup

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
insert into public.session_participants (session_id, profile_id, kind)
values ('50000000-0000-0000-0000-000000000001',
        '22222222-2222-2222-2222-222222222222', 'toast');

set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select is(
  (select type from public.notifications where subject_type = 'session'),
  'session_toast',
  'Der Gastgeber bekommt die Prost-Benachrichtigung'
);

-- Zieht Bert zurück, verschwindet sie.
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
delete from public.session_participants
 where session_id = '50000000-0000-0000-0000-000000000001'
   and profile_id = '22222222-2222-2222-2222-222222222222';
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select is(
  (select count(*) from public.notifications where subject_type = 'session'),
  0::bigint,
  'Zurückgezogener Prost verschwindet aus der Glocke'
);

-- Schalter vorhanden.
select is(
  (select value from public.app_config where key = 'feedback_enabled'),
  'true',
  'feedback_enabled ist gesetzt'
);

select * from finish();
rollback;
