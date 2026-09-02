-- Benachrichtigungen für Freundschaftsanfragen (Migration 0031).
--
-- Geprüft wird der Trigger, nicht die Oberfläche: Eine Anfrage muss beim
-- Empfänger eine Zeile erzeugen — und beim Absender KEINE. Und was
-- zurückgenommen wird, muss auch aus der Glocke verschwinden, sonst führt
-- sie zu einer Zeile, die es nicht mehr gibt.

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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'anna');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'bert');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'clara');

-- ============================================================================
-- Anna fragt Bert an.
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

insert into public.friendships (id, requester_id, addressee_id)
values ('f0000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222');

-- Anna selbst sieht dazu nichts — sie hat gefragt, nicht bekommen.
select is(
  (select count(*) from public.notifications),
  0::bigint,
  'Der Absender bekommt keine Benachrichtigung über seine eigene Anfrage'
);

-- Bert sieht genau eine.
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is(
  (select count(*) from public.notifications),
  1::bigint,
  'Der Empfänger bekommt genau eine Benachrichtigung'
);
select is(
  (select type from public.notifications limit 1),
  'friend_request',
  '… vom Typ friend_request'
);
select is(
  (select actor_id from public.notifications limit 1),
  '11111111-1111-1111-1111-111111111111'::uuid,
  '… mit dem Absender als Akteur'
);

-- Clara, unbeteiligt, sieht nichts.
set local "request.jwt.claims" =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
select is(
  (select count(*) from public.notifications),
  0::bigint,
  'Unbeteiligte sehen fremde Benachrichtigungen nicht'
);

-- Niemand darf Benachrichtigungen von Hand einfügen — nur der Trigger.
select throws_ok(
  $$ insert into public.notifications (recipient_id, type)
     values ('33333333-3333-3333-3333-333333333333', 'friend_request') $$,
  '42501',
  null,
  'Direktes Einfügen in notifications ist gesperrt (kein Insert-Policy)'
);

-- ============================================================================
-- Bert nimmt an.
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

update public.friendships set status = 'accepted'
 where id = 'f0000000-0000-0000-0000-000000000001';

select is(
  (select count(*) from public.notifications where type = 'friend_request'),
  0::bigint,
  'Nach dem Annehmen ist die offene Anfrage aus Berts Glocke verschwunden'
);

-- Anna erfährt vom Annehmen.
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select is(
  (select type from public.notifications limit 1),
  'friend_accepted',
  'Der Absender erfährt, dass angenommen wurde'
);

-- ============================================================================
-- Anna fragt Clara an und nimmt zurück (Zeile wird gelöscht).
-- ============================================================================

insert into public.friendships (id, requester_id, addressee_id)
values ('f0000000-0000-0000-0000-000000000002',
        '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333');

set local "request.jwt.claims" =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
select is(
  (select count(*) from public.notifications where type = 'friend_request'),
  1::bigint,
  'Clara hat die Anfrage in der Glocke'
);

set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
delete from public.friendships
 where id = 'f0000000-0000-0000-0000-000000000002';

set local "request.jwt.claims" =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
select is(
  (select count(*) from public.notifications),
  0::bigint,
  'Zurückgenommen heißt auch aus der Glocke verschwunden'
);

select * from finish();
rollback;
