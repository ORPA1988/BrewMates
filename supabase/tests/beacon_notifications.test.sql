-- Benachrichtigungen für Beacons (Migration 0039).
--
-- Der Kern ist nicht „es kommt etwas an", sondern **wer** etwas bekommt.
-- Die Empfängerliste muss deckungsgleich mit `sessions_select` sein: Eine
-- Benachrichtigung über eine Runde, die man beim Hintippen nicht sehen
-- darf, wäre schlimmer als gar keine.

begin;
select plan(11);

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

-- anna ist die Gastgeberin.
select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'anna');
-- bert: Freund (Kreis „Freund")
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'bert');
-- clara: nur „Bekannte" — sieht den Beacon nicht, also auch keinen Push
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'clara');
-- dora: befreundet, hat anna aber blockiert
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'dora');
-- emil: gar nicht befreundet, aber in derselben Crew
select pg_temp.mkuser('55555555-5555-5555-5555-555555555555', 'emil');

set local role postgres;

insert into public.friendships
  (id, requester_id, addressee_id, status, requester_tier, addressee_tier)
values
  ('f0000000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'accepted', 'freund', 'freund'),
  ('f0000000-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   '33333333-3333-3333-3333-333333333333', 'accepted', 'bekannter', 'freund'),
  ('f0000000-0000-0000-0000-000000000003',
   '11111111-1111-1111-1111-111111111111',
   '44444444-4444-4444-4444-444444444444', 'accepted', 'freund', 'freund');

insert into public.blocks (blocker_id, blocked_id)
values ('44444444-4444-4444-4444-444444444444',
        '11111111-1111-1111-1111-111111111111');

-- ============================================================================
-- Anna startet einen Beacon für Freunde.
-- ============================================================================

insert into public.sessions
  (id, host_id, visibility, status, started_at, expires_at)
values ('50000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111',
        'friends', 'active', now(), now() + interval '3 hours');

select is(
  (select count(*) from public.notifications where type = 'beacon'),
  1::bigint,
  'Genau einer wird geweckt: der Freund im Kreis „Freund"'
);

select is(
  (select recipient_id from public.notifications where type = 'beacon'),
  '22222222-2222-2222-2222-222222222222'::uuid,
  'Und zwar bert'
);

select is(
  (select count(*) from public.notifications
    where type = 'beacon'
      and recipient_id = '33333333-3333-3333-3333-333333333333'),
  0::bigint,
  'Eine Bekannte sieht den Beacon nicht — also klingelt bei ihr nichts'
);

select is(
  (select count(*) from public.notifications
    where type = 'beacon'
      and recipient_id = '44444444-4444-4444-4444-444444444444'),
  0::bigint,
  'Wer blockiert hat, wird nicht geweckt'
);

select is(
  (select count(*) from public.notifications
    where type = 'beacon'
      and recipient_id = '11111111-1111-1111-1111-111111111111'),
  0::bigint,
  'Die Gastgeberin benachrichtigt sich nicht selbst'
);

-- ============================================================================
-- Die Spam-Bremse: derselbe Mensch, zweiter Beacon in derselben Stunde.
-- ============================================================================

insert into public.sessions
  (id, host_id, visibility, status, started_at, expires_at)
values ('50000000-0000-0000-0000-000000000002',
        '11111111-1111-1111-1111-111111111111',
        'friends', 'active', now(), now() + interval '3 hours');

select is(
  (select count(*) from public.notifications where type = 'beacon'),
  1::bigint,
  'Der zweite Beacon binnen einer Stunde weckt niemanden noch einmal'
);

-- ============================================================================
-- Beenden räumt die Glocke auf …
-- ============================================================================

update public.sessions set status = 'ended', ended_at = now()
 where id = '50000000-0000-0000-0000-000000000001';

select is(
  (select count(*) from public.notifications where type = 'beacon'),
  0::bigint,
  'Endet die Runde, verschwindet die Benachrichtigung dazu'
);

-- ============================================================================
-- … aber die Bremse hängt NICHT an der Glocke.
-- ============================================================================

insert into public.sessions
  (id, host_id, visibility, status, started_at, expires_at)
values ('50000000-0000-0000-0000-000000000003',
        '11111111-1111-1111-1111-111111111111',
        'friends', 'active', now(), now() + interval '3 hours');

select is(
  (select count(*) from public.notifications where type = 'beacon'),
  0::bigint,
  'Starten, beenden, starten setzt die Spam-Bremse nicht zurück'
);

-- ============================================================================
-- Crew-Beacon: Mitglieder ja, Freunde außerhalb der Crew nein.
-- ============================================================================

insert into public.crews (id, name, owner_id)
values ('c0000000-0000-0000-0000-000000000001', 'Stammtisch',
        '11111111-1111-1111-1111-111111111111');
insert into public.crew_members (crew_id, profile_id)
values ('c0000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111'),
       ('c0000000-0000-0000-0000-000000000001',
        '55555555-5555-5555-5555-555555555555');

-- Bruno startet die Crew-Runde, damit die Bremse von anna nicht greift.
select pg_temp.mkuser('66666666-6666-6666-6666-666666666666', 'bruno');
insert into public.crew_members (crew_id, profile_id)
values ('c0000000-0000-0000-0000-000000000001',
        '66666666-6666-6666-6666-666666666666');

insert into public.sessions
  (id, host_id, visibility, crew_id, status, started_at, expires_at)
values ('50000000-0000-0000-0000-000000000004',
        '66666666-6666-6666-6666-666666666666',
        'crew', 'c0000000-0000-0000-0000-000000000001',
        'active', now(), now() + interval '3 hours');

select is(
  (select count(*) from public.notifications where type = 'beacon'),
  2::bigint,
  'Die Crew-Runde weckt die beiden anderen Mitglieder'
);

select is(
  (select count(*) from public.notifications
    where type = 'beacon'
      and recipient_id = '22222222-2222-2222-2222-222222222222'),
  0::bigint,
  'Ein Freund außerhalb der Crew bekommt nichts — er sieht sie ja auch nicht'
);

-- ============================================================================
-- Eine private Runde ist privat.
-- ============================================================================

select pg_temp.mkuser('77777777-7777-7777-7777-777777777777', 'frida');
insert into public.friendships
  (id, requester_id, addressee_id, status, requester_tier, addressee_tier)
values ('f0000000-0000-0000-0000-000000000004',
        '77777777-7777-7777-7777-777777777777',
        '22222222-2222-2222-2222-222222222222', 'accepted', 'freund', 'freund');

insert into public.sessions
  (id, host_id, visibility, status, started_at, expires_at)
values ('50000000-0000-0000-0000-000000000005',
        '77777777-7777-7777-7777-777777777777',
        'private', 'active', now(), now() + interval '3 hours');

select is(
  (select count(*) from public.notifications
    where type = 'beacon' and actor_id = '77777777-7777-7777-7777-777777777777'),
  0::bigint,
  'Eine private Runde weckt niemanden'
);

select * from finish();
rollback;
