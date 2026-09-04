-- Geplante Sessions: Wer sieht eine Verabredung, und was erzwingt die
-- Datenbank?
--
-- Der Anlass für diesen Test steht in `docs/features/39`: Die Annahme,
-- `sessions_select` filtere nur nach Sichtbarkeit, war **falsch** — die
-- Policy schloss alles aus, was nicht gerade läuft. 0049 erweitert sie,
-- und eine Policy, die über den Aufenthaltsort entscheidet, erweitert
-- man nicht auf Zuruf.
--
-- Geprüft wird gegen die Policy, nicht gegen die App. Eine Regel, die
-- nur die App befolgt, ist keine.
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'alice');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'freund');
select pg_temp.mkuser('55555555-5555-5555-5555-555555555555', 'fremd');

-- Der Gastgeber stuft alice als „freund" ein — das ist die Seite, auf
-- die es ankommt: Der Besitzer der Information entscheidet.
insert into public.friendships
  (id, requester_id, addressee_id, status, requester_tier, addressee_tier)
values
  ('aaaaaaaa-0000-0000-0000-000000000002',
   '33333333-3333-3333-3333-333333333333',
   '11111111-1111-1111-1111-111111111111', 'accepted', 'freund', 'freund');

-- Drei Verabredungen des Freundes: eine kommende, eine gerade erst
-- verstrichene (innerhalb der Karenz) und eine längst tote.
insert into public.sessions
  (id, host_id, visibility, status, scheduled_for, started_at, expires_at)
values
  ('eeeeeeee-0000-0000-0000-000000000001',
   '33333333-3333-3333-3333-333333333333', 'friends', 'planned',
   now() + interval '2 days', now(), now() + interval '3 hours'),
  ('eeeeeeee-0000-0000-0000-000000000002',
   '33333333-3333-3333-3333-333333333333', 'friends', 'planned',
   now() - interval '1 hour', now(), now() + interval '3 hours'),
  ('eeeeeeee-0000-0000-0000-000000000003',
   '33333333-3333-3333-3333-333333333333', 'friends', 'planned',
   now() - interval '5 hours', now(), now() + interval '3 hours');

-- Und eine des Fremden, damit „sieht sie nicht" nicht daran liegt, dass
-- es sie gar nicht gibt.
insert into public.sessions
  (id, host_id, visibility, status, scheduled_for, started_at, expires_at)
values
  ('eeeeeeee-0000-0000-0000-000000000009',
   '55555555-5555-5555-5555-555555555555', 'friends', 'planned',
   now() + interval '2 days', now(), now() + interval '3 hours');

-- Eine LAUFENDE Session des Fremden, mit Ort. Sie gehört in den
-- Kartenzähler — ohne sie wäre die Zähler-Prüfung unten wertlos: Null
-- käme auch heraus, wenn gar nichts da wäre.
insert into public.sessions
  (id, host_id, visibility, status, started_at, expires_at,
   latitude, longitude)
values
  ('eeeeeeee-0000-0000-0000-00000000000f',
   '55555555-5555-5555-5555-555555555555', 'friends', 'active',
   now(), now() + interval '3 hours', 47.80, 13.04);

-- ============================================================================
-- Was die Datenbank erzwingt — noch ohne RLS, als Eigentümer.
-- ============================================================================

select throws_ok(
  $$insert into public.sessions (host_id, visibility, status)
    values ('33333333-3333-3333-3333-333333333333', 'friends', 'planned')$$,
  '23514',
  null,
  'Eine Verabredung ohne Termin lehnt die Datenbank ab'
);

select throws_ok(
  $$insert into public.sessions
      (host_id, visibility, status, scheduled_for, latitude, longitude)
    values ('33333333-3333-3333-3333-333333333333', 'friends', 'planned',
            now() + interval '1 day', 47.80, 13.04)$$,
  '23514',
  null,
  'Eine Verabredung mit Standort lehnt die Datenbank ab — sie behauptet '
  'eine Absicht, keine Anwesenheit'
);

select lives_ok(
  $$insert into public.sessions
      (id, host_id, visibility, status, scheduled_for)
    values ('eeeeeeee-0000-0000-0000-00000000000a',
            '33333333-3333-3333-3333-333333333333', 'friends', 'planned',
            now() + interval '1 day')$$,
  'Mit Termin und ohne Standort geht sie durch'
);
delete from public.sessions
 where id = 'eeeeeeee-0000-0000-0000-00000000000a';

-- ============================================================================
-- Ab hier als alice, mit echter RLS.
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  (select count(*)::int from public.sessions
    where id = 'eeeeeeee-0000-0000-0000-000000000001'),
  1,
  'Ein Freund sieht die kommende Verabredung — genau das konnte die alte '
  'Policy nicht'
);

select is(
  (select count(*)::int from public.sessions
    where id = 'eeeeeeee-0000-0000-0000-000000000002'),
  1,
  'Innerhalb der Karenz bleibt sie sichtbar: Wer eine Stunde zu spät '
  'startet, soll seine Runde noch haben'
);

select is(
  (select count(*)::int from public.sessions
    where id = 'eeeeeeee-0000-0000-0000-000000000003'),
  0,
  'Nach der Karenz ist sie weg, auch für den Freund'
);

select is(
  (select count(*)::int from public.sessions
    where id = 'eeeeeeee-0000-0000-0000-000000000009'),
  0,
  'Die Verabredung eines Fremden bleibt unsichtbar — die Sichtbarkeit '
  'hängt weiter allein am Kreis'
);

-- Der Kartenzähler: Er darf geplante Sessions nicht mitzählen. Nicht
-- weil die Policy sie verbirgt, sondern weil sie keinen Ort haben —
-- diese zweite Bedingung ist der eigentliche Schutz.
select is(
  public.count_other_active_sessions(40.0, 5.0, 55.0, 20.0),
  1,
  'Der Kartenzähler kennt genau die eine laufende Session des Fremden — '
  'die drei Verabredungen zählen nicht mit'
);

-- ============================================================================
-- Der Gastgeber sieht seine eigene immer.
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select is(
  (select count(*)::int from public.sessions
    where id = 'eeeeeeee-0000-0000-0000-000000000003'),
  1,
  'Der Gastgeber sieht auch die längst verstrichene — sonst könnte er '
  'sie nicht einmal aufräumen'
);

-- ============================================================================
-- Aufräumen
-- ============================================================================

reset role;

select public.end_expired_sessions();

select is(
  (select status::text from public.sessions
    where id = 'eeeeeeee-0000-0000-0000-000000000003'),
  'ended',
  'Was drei Stunden nach dem Termin nie gestartet wurde, räumt der Cron ab'
);

select is(
  (select status::text from public.sessions
    where id = 'eeeeeeee-0000-0000-0000-000000000001'),
  'planned',
  'Die kommende Verabredung lässt er in Ruhe'
);

select * from finish();
rollback;
