-- Freunde in eine Crew einladen (Migration 0044).
--
-- Alle Prüfungen laufen in der Rolle `authenticated` — die Lehre aus
-- 0042 und 0043: Wer eine Regel prüft, die an Rechten hängt, muss sie in
-- der Rolle prüfen, die sie betrifft. Als `postgres` wäre hier jede
-- Zeile grün und keine Aussage wahr.

begin;
select plan(14);

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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'anna');   -- Crew
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'bert');   -- Freund
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'clara');  -- fremd
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'dora');   -- Freund, nicht in der Crew

set local role postgres;

insert into public.crews (id, name, owner_id)
values ('c0000000-0000-0000-0000-000000000001', 'Stammtisch',
        '11111111-1111-1111-1111-111111111111');
insert into public.crew_members (crew_id, profile_id, role)
values ('c0000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111', 'owner');

-- anna ist mit bert und dora befreundet, mit clara nicht.
insert into public.friendships
  (id, requester_id, addressee_id, status)
values
  ('f0000000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'accepted'),
  ('f0000000-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   '44444444-4444-4444-4444-444444444444', 'accepted');

-- ============================================================================
-- Einladen darf nur, wer dazugehört — und nur Freunde
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$insert into public.crew_invites (crew_id, invitee_id, inviter_id)
    values ('c0000000-0000-0000-0000-000000000001',
            '22222222-2222-2222-2222-222222222222',
            '11111111-1111-1111-1111-111111111111')$$,
  'Ein Mitglied lädt einen Freund ein'
);

select throws_ok(
  $$insert into public.crew_invites (crew_id, invitee_id, inviter_id)
    values ('c0000000-0000-0000-0000-000000000001',
            '33333333-3333-3333-3333-333333333333',
            '11111111-1111-1111-1111-111111111111')$$,
  '42501',
  null,
  'Wer kein Freund ist, bekommt keine Einladung — sonst waere sie ein '
  'Weg, Fremde anzuschreiben'
);

select throws_ok(
  $$insert into public.crew_invites (crew_id, invitee_id, inviter_id)
    values ('c0000000-0000-0000-0000-000000000001',
            '44444444-4444-4444-4444-444444444444',
            '22222222-2222-2222-2222-222222222222')$$,
  '42501',
  null,
  'Und niemand laedt in fremdem Namen ein'
);

-- dora gehört nicht zur Crew und kann deshalb nicht einladen.
set local "request.jwt.claims" =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

select throws_ok(
  $$insert into public.crew_invites (crew_id, invitee_id, inviter_id)
    values ('c0000000-0000-0000-0000-000000000001',
            '11111111-1111-1111-1111-111111111111',
            '44444444-4444-4444-4444-444444444444')$$,
  '42501',
  null,
  'Wer nicht in der Crew ist, laedt auch niemanden hinein'
);

-- ============================================================================
-- Sehen darf sie der Eingeladene und die Crew — sonst niemand
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
select is(
  (select count(*) from public.crew_invites),
  1::bigint,
  'Der Eingeladene sieht seine Einladung'
);

select is(
  (select count(*) from public.notifications where type = 'crew_invite'),
  1::bigint,
  'Und bekommt eine Meldung in die Glocke'
);

-- Er sieht die Crew aber noch NICHT: Einladung ist nicht Mitgliedschaft.
select is(
  (select count(*) from public.crews),
  0::bigint,
  'Eine Einladung ist noch keine Mitgliedschaft'
);

set local "request.jwt.claims" =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
select is(
  (select count(*) from public.crew_invites),
  0::bigint,
  'Unbeteiligte sehen keine Einladungen'
);

-- ============================================================================
-- Annehmen
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select lives_ok(
  $$insert into public.crew_members (crew_id, profile_id)
    values ('c0000000-0000-0000-0000-000000000001',
            '22222222-2222-2222-2222-222222222222')$$,
  'Annehmen heisst: sich selbst eintragen'
);

select lives_ok(
  $$delete from public.crew_invites
     where crew_id = 'c0000000-0000-0000-0000-000000000001'
       and invitee_id = '22222222-2222-2222-2222-222222222222'$$,
  'und die Einladung wegraeumen'
);

select is(
  (select count(*) from public.crews),
  1::bigint,
  'Danach sieht er die Crew'
);

select is(
  (select count(*) from public.notifications where type = 'crew_invite'),
  0::bigint,
  'Und die Meldung ist weg — sie zeigte sonst auf eine Einladung, die es '
  'nicht mehr gibt'
);

-- ============================================================================
-- Ablehnen und Zuruecknehmen
-- ============================================================================

set local role postgres;
insert into public.crew_invites (crew_id, invitee_id, inviter_id)
values ('c0000000-0000-0000-0000-000000000001',
        '44444444-4444-4444-4444-444444444444',
        '11111111-1111-1111-1111-111111111111');

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

select lives_ok(
  $$delete from public.crew_invites
     where invitee_id = '44444444-4444-4444-4444-444444444444'$$,
  'Der Eingeladene kann ablehnen'
);

set local role postgres;
select is(
  (select count(*) from public.crew_invites),
  0::bigint,
  'Und die Einladung ist damit fort'
);

select * from finish();
rollback;
