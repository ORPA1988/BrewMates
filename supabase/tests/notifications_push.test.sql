-- Push-Webhook (Migration 0033): Fehlt die Konfiguration, geht die Anfrage
-- trotzdem durch. Push ist ein Zusatz — nie ein Grund, dass etwas scheitert.
begin;
select plan(4);

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

select is(
  (select count(*) from vault.decrypted_secrets
    where name = 'notify_webhook_secret'),
  0::bigint,
  'Im Testaufbau gibt es kein Webhook-Geheimnis'
);

select has_trigger('public', 'notifications', 'notifications_push',
  'Der Push-Trigger haengt an notifications');

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ insert into public.friendships (requester_id, addressee_id)
     values ('11111111-1111-1111-1111-111111111111',
             '22222222-2222-2222-2222-222222222222') $$,
  'Ohne Push-Konfiguration geht die Anfrage trotzdem durch (nur Warnung)'
);

-- Das Geheimnis ist fuer Angemeldete tabu (0034).
select throws_ok(
  $$ select public.notify_webhook_secret() $$,
  '42501',
  null,
  'Angemeldete Nutzer duerfen das Webhook-Geheimnis nicht lesen'
);

select * from finish();
rollback;
