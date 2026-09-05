-- Erinnerungen an eine Verabredung: Wer wird geweckt, wie oft, und wer
-- ausdrücklich nicht?
--
-- Der wichtigste Test ist der über die Wiederholung. Der Cron läuft alle
-- fünf Minuten; ohne Gedächtnis bekäme jeder Zusagende zwei Stunden lang
-- alle fünf Minuten dieselbe Meldung — vierundzwanzigmal.
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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'gastgeber');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'freundin');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'bekannter');
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'absagerin');

-- Die Freundin ist im Kreis „freund", der Bekannte darunter.
insert into public.friendships
  (id, requester_id, addressee_id, status, requester_tier, addressee_tier)
values
  ('aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'accepted', 'freund', 'freund'),
  ('aaaaaaaa-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   '33333333-3333-3333-3333-333333333333', 'accepted', 'bekannter', 'freund'),
  ('aaaaaaaa-0000-0000-0000-000000000003',
   '11111111-1111-1111-1111-111111111111',
   '44444444-4444-4444-4444-444444444444', 'accepted', 'freund', 'freund');

-- ============================================================================
-- Beim Anlegen
-- ============================================================================

insert into public.sessions
  (id, host_id, visibility, status, scheduled_for, started_at, expires_at)
values
  ('55550000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'friends', 'planned',
   now() + interval '3 days', now(), now() + interval '3 days 3 hours');

select is(
  (select count(*)::int from public.notifications
    where type = 'session_planned'
      and subject_id = '55550000-0000-0000-0000-000000000001'),
  2,
  'Beide im Kreis „freund" erfahren von der Verabredung'
);

select is(
  (select count(*)::int from public.notifications
    where type = 'session_planned'
      and recipient_id = '33333333-3333-3333-3333-333333333333'),
  0,
  'Ein Bekannter nicht — dieselbe Grenze wie beim Beacon'
);

-- Eine Änderung an der Verabredung darf die Meldung nicht wiederholen.
update public.sessions set message = 'Doch im Augustiner'
 where id = '55550000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.notifications
    where type = 'session_planned'
      and subject_id = '55550000-0000-0000-0000-000000000001'),
  2,
  'Ein Nachtrag am Text weckt niemanden noch einmal'
);

-- ============================================================================
-- Die Erinnerung kurz vorher
-- ============================================================================

-- Zwei antworten, eine sagt zu, eine ab.
insert into public.session_participants (session_id, profile_id, kind)
values
  ('55550000-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'joined'),
  ('55550000-0000-0000-0000-000000000001',
   '44444444-4444-4444-4444-444444444444', 'declined');

-- Noch drei Tage hin: Es ist nichts zu erinnern.
select public.remind_planned_sessions();

select is(
  (select count(*)::int from public.notifications
    where type = 'session_reminder'),
  0,
  'Drei Tage vorher erinnert noch nichts'
);

-- Termin auf „in einer Stunde" ziehen.
update public.sessions
   set scheduled_for = now() + interval '1 hour'
 where id = '55550000-0000-0000-0000-000000000001';

select public.remind_planned_sessions();

select is(
  (select count(*)::int from public.notifications
    where type = 'session_reminder'),
  2,
  'Der Gastgeber und die Zusagende werden erinnert'
);

select ok(
  exists (select 1 from public.notifications
           where type = 'session_reminder'
             and recipient_id = '11111111-1111-1111-1111-111111111111'),
  'Auch der Gastgeber — er ist der Einzige, der die Runde starten kann'
);

select is(
  (select count(*)::int from public.notifications
    where type = 'session_reminder'
      and recipient_id = '44444444-4444-4444-4444-444444444444'),
  0,
  'Wer abgesagt hat, wird nicht erinnert'
);

-- ============================================================================
-- Der Test, um den es eigentlich geht.
-- ============================================================================

select public.remind_planned_sessions();
select public.remind_planned_sessions();
select public.remind_planned_sessions();

select is(
  (select count(*)::int from public.notifications
    where type = 'session_reminder'),
  2,
  'Der Cron läuft alle fünf Minuten — erinnert wird trotzdem genau einmal'
);

-- ============================================================================
-- Aus der Verabredung wird eine Runde.
-- ============================================================================

update public.sessions
   set status = 'active',
       started_at = now(),
       expires_at = now() + interval '3 hours'
 where id = '55550000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.notifications
    where type = 'beacon'
      and subject_id = '55550000-0000-0000-0000-000000000001'),
  2,
  'Der Start meldet sich als Beacon — jetzt ist die Runde wirklich '
  'unterwegs'
);

select * from finish();
rollback;
