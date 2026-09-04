-- Zu- und Absagen auf einen Beacon (Migration 0047).
--
-- Zwei Dinge werden hier geprüft, und das zweite ist das wichtigere:
--
-- 1. Eine Absage kommt als Absage beim Gastgeber an. Der Trigger aus 0037
--    behandelte alles, was nicht 'toast' war, als Zusage — mit dem dritten
--    Wert wäre eine Absage als „ist dabei" gemeldet worden, also als das
--    glatte Gegenteil.
-- 2. Wer den Beacon sehen darf, sieht auch die Antworten. Sonst wüsste
--    niemand außer dem Gastgeber, wer kommt — und genau darum geht es.

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

-- anna lädt ein, bert und clara antworten, dora ist unbeteiligt.
select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'anna');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'bert');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'clara');
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'dora');

set local role postgres;

insert into public.friendships
  (id, requester_id, addressee_id, status, requester_tier, addressee_tier)
values
  ('f0000000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'accepted', 'freund', 'freund'),
  ('f0000000-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   '33333333-3333-3333-3333-333333333333', 'accepted', 'freund', 'freund');

insert into public.sessions
  (id, host_id, visibility, status, started_at, expires_at)
values ('50000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111',
        'friends', 'active', now(), now() + interval '3 hours');

-- Die Beacon-Meldungen aus 0039 stehen schon in der Tabelle; sie sollen
-- die Zählungen unten nicht verfälschen.
delete from public.notifications where type = 'beacon';

-- ============================================================================
-- Bert sagt zu, Clara sagt ab — beide in ihrer eigenen Rolle.
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
insert into public.session_participants (session_id, profile_id, kind)
values ('50000000-0000-0000-0000-000000000001',
        '22222222-2222-2222-2222-222222222222', 'joined');

set local "request.jwt.claims" =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
insert into public.session_participants (session_id, profile_id, kind)
values ('50000000-0000-0000-0000-000000000001',
        '33333333-3333-3333-3333-333333333333', 'declined');

reset role;

select is(
  (select type from public.notifications
    where actor_id = '22222222-2222-2222-2222-222222222222'),
  'session_joined',
  'Eine Zusage kommt als Zusage an'
);

select is(
  (select type from public.notifications
    where actor_id = '33333333-3333-3333-3333-333333333333'),
  'session_declined',
  'Eine Absage kommt als Absage an — und nicht als das Gegenteil'
);

select is(
  (select count(distinct recipient_id) from public.notifications),
  1::bigint,
  'Beide Meldungen gehen an die Gastgeberin und an sonst niemanden'
);

-- ============================================================================
-- Sehen darf die Antworten, wer den Beacon sehen darf.
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
select is(
  (select count(*) from public.session_participants),
  2::bigint,
  'Bert sieht beide Antworten — sonst wüsste nur die Gastgeberin, wer kommt'
);

set local "request.jwt.claims" =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';
select is(
  (select count(*) from public.session_participants),
  0::bigint,
  'Dora sieht nichts: Wer den Beacon nicht sieht, sieht auch die Antworten nicht'
);

-- ============================================================================
-- Umentscheiden: Clara kommt doch.
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
delete from public.session_participants
 where session_id = '50000000-0000-0000-0000-000000000001'
   and profile_id = '33333333-3333-3333-3333-333333333333'
   and kind in ('joined', 'declined');
insert into public.session_participants (session_id, profile_id, kind)
values ('50000000-0000-0000-0000-000000000001',
        '33333333-3333-3333-3333-333333333333', 'joined');
reset role;

select is(
  (select count(*) from public.session_participants
    where profile_id = '33333333-3333-3333-3333-333333333333'),
  1::bigint,
  'Nach dem Umentscheiden steht genau eine Antwort da, nicht zwei'
);

select is(
  (select type from public.notifications
    where actor_id = '33333333-3333-3333-3333-333333333333'),
  'session_joined',
  'Und die alte Meldung ist mitgegangen'
);

-- ============================================================================
-- Prost steht daneben: „kann nicht, trink eins auf mich".
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
insert into public.session_participants (session_id, profile_id, kind)
values ('50000000-0000-0000-0000-000000000001',
        '22222222-2222-2222-2222-222222222222', 'toast');
reset role;

select is(
  (select count(*) from public.session_participants
    where profile_id = '22222222-2222-2222-2222-222222222222'),
  2::bigint,
  'Zuprosten verdrängt die Zusage nicht — die beiden Fragen sind getrennt'
);

-- Und niemand kann im Namen eines anderen antworten (Policy aus 0001).
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
select throws_ok(
  $$ insert into public.session_participants (session_id, profile_id, kind)
     values ('50000000-0000-0000-0000-000000000001',
             '33333333-3333-3333-3333-333333333333', 'declined') $$,
  '42501',
  null,
  'Niemand sagt für jemand anderen ab'
);
reset role;

select * from finish();
rollback;
