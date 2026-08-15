-- RLS-Tests: Wer sieht wen, und wo?
--
-- Die gesamte Privatsphäre von BrewMates hängt an Row Level Security.
-- Bis 2026-08-15 war davon nichts getestet (Backlog A-2) — die Regeln
-- galten, weil sie jemand gelesen hatte. Das reicht bei einer App nicht,
-- deren heikelste Angabe der Aufenthaltsort ist.
--
-- Geprüft wird gegen die Policy, nicht gegen die App. Eine Regel, die nur
-- die App befolgt, ist keine.
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

begin;
select plan(14);

-- ============================================================================
-- Aufbau: eine Betrachterin (alice) und fünf Gastgeber, je einer pro
-- Beziehungsart. Der Kreis ist die Einstufung, die der GASTGEBER alice
-- gegeben hat — nicht umgekehrt. Der Besitzer der Information entscheidet.
-- ============================================================================

create or replace function pg_temp.mkuser(p_id uuid, p_name text)
returns void language plpgsql as $$
begin
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, created_at, updated_at)
  values (p_id, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', p_name || '@test.invalid', '', now(), now());
  -- handle_new_user legt das Profil per Trigger an; Namen fixieren.
  update public.profiles set username = p_name, display_name = p_name
   where id = p_id;
end $$;

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'alice');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'bekannter');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'freund');
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'buddy');
select pg_temp.mkuser('55555555-5555-5555-5555-555555555555', 'fremd');
select pg_temp.mkuser('66666666-6666-6666-6666-666666666666', 'crewkollege');

-- Freundschaften: Gastgeber ist requester, alice addressee. Damit trägt
-- requester_tier die Einstufung, die der Gastgeber alice gibt.
insert into public.friendships
  (id, requester_id, addressee_id, status, requester_tier, addressee_tier)
values
  ('aaaaaaaa-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111', 'accepted', 'bekannter', 'freund'),
  ('aaaaaaaa-0000-0000-0000-000000000002',
   '33333333-3333-3333-3333-333333333333',
   '11111111-1111-1111-1111-111111111111', 'accepted', 'freund', 'freund'),
  ('aaaaaaaa-0000-0000-0000-000000000003',
   '44444444-4444-4444-4444-444444444444',
   '11111111-1111-1111-1111-111111111111', 'accepted', 'buddy', 'freund');

-- Crew: alice und crewkollege sind Mitglieder, aber NICHT befreundet.
insert into public.crews (id, name, emoji, owner_id)
values ('cccccccc-0000-0000-0000-000000000001', 'Testcrew', '🍻',
        '66666666-6666-6666-6666-666666666666');
insert into public.crew_members (crew_id, profile_id, role) values
  ('cccccccc-0000-0000-0000-000000000001',
   '66666666-6666-6666-6666-666666666666', 'owner'),
  ('cccccccc-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'member');

-- Je eine laufende Session, alle am selben Ort (Salzburg).
insert into public.sessions
  (id, host_id, visibility, crew_id, status, started_at, expires_at,
   latitude, longitude)
select
  ('dddddddd-0000-0000-0000-00000000000' || n)::uuid, host, vis, crew,
  'active', now(), now() + interval '3 hours', 47.80, 13.04
from (values
  (1, '22222222-2222-2222-2222-222222222222'::uuid, 'friends'::visibility, null::uuid),
  (2, '33333333-3333-3333-3333-333333333333'::uuid, 'friends'::visibility, null::uuid),
  (3, '44444444-4444-4444-4444-444444444444'::uuid, 'friends'::visibility, null::uuid),
  (4, '55555555-5555-5555-5555-555555555555'::uuid, 'friends'::visibility, null::uuid),
  (5, '66666666-6666-6666-6666-666666666666'::uuid, 'crew'::visibility,
      'cccccccc-0000-0000-0000-000000000001'::uuid)
) as t(n, host, vis, crew);

-- Bierlaune bei allen dreien mit Freundschaft.
update public.profiles set thirsty_until = now() + interval '2 hours'
 where id in ('22222222-2222-2222-2222-222222222222',
              '33333333-3333-3333-3333-333333333333',
              '44444444-4444-4444-4444-444444444444');

-- ============================================================================
-- Ab hier als alice, mit echter RLS.
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- --- Beacons: der Kern der Ortssichtbarkeit --------------------------------

select is(
  (select count(*)::int from public.sessions
    where host_id = '22222222-2222-2222-2222-222222222222'),
  0,
  'Bekannte sehen den Beacon NICHT — der Ort ist die heikelste Angabe'
);

select is(
  (select count(*)::int from public.sessions
    where host_id = '33333333-3333-3333-3333-333333333333'),
  1,
  'Freunde sehen den Beacon'
);

select is(
  (select count(*)::int from public.sessions
    where host_id = '44444444-4444-4444-4444-444444444444'),
  1,
  'Best Buddys sehen den Beacon'
);

select is(
  (select count(*)::int from public.sessions
    where host_id = '55555555-5555-5555-5555-555555555555'),
  0,
  'Fremde sehen den Beacon nie'
);

select is(
  (select count(*)::int from public.sessions
    where host_id = '66666666-6666-6666-6666-666666666666'),
  1,
  'Crew-Mitglieder sehen die Crew-Session auch ohne Freundschaft'
);

select is(
  (select count(*)::int from public.sessions),
  3,
  'Insgesamt genau drei sichtbare Sessions, keine weitere'
);

-- --- Keine Position für Nicht-Freunde --------------------------------------

select is(
  (select count(*)::int from public.sessions
    where latitude is not null
      and host_id not in ('33333333-3333-3333-3333-333333333333',
                          '44444444-4444-4444-4444-444444444444',
                          '66666666-6666-6666-6666-666666666666')),
  0,
  'Keine Koordinaten von jemandem, dessen Zeile nicht sichtbar sein darf'
);

-- --- Der Zähler: sichtbar und gezählt müssen zusammen alles ergeben --------

select is(
  public.count_other_active_sessions(47.0, 12.0, 48.5, 14.0),
  2,
  'Gezählt werden genau die zwei verborgenen (Bekannter + Fremder)'
);

select is(
  (select count(*)::int from public.sessions where host_id <> auth.uid())
    + public.count_other_active_sessions(47.0, 12.0, 48.5, 14.0),
  5,
  'Sichtbar + gezählt = alle fünf. Keine Lücke, keine Dopplung'
);

-- --- Bierlaune folgt derselben Abstufung -----------------------------------

select is(
  (select count(*)::int from public.thirsty_friends()),
  2,
  'Bierlaune sehen nur Freunde und Buddys, nicht Bekannte'
);

select is(
  (select count(*)::int from public.thirsty_friends()
    where username = 'bekannter'),
  0,
  'Der Bekannte taucht in der Bierlaune-Liste nicht auf'
);

-- Spaltenrecht aus 0025: direkt lesen ist gesperrt, auch für Freunde.
select throws_ok(
  'select thirsty_until from public.profiles limit 1',
  '42501',
  null,
  'thirsty_until ist als Spalte gesperrt — gelesen wird über die Funktionen'
);

-- --- tier_for beantwortet nur eigene Paare ---------------------------------

select is(
  public.tier_for('33333333-3333-3333-3333-333333333333',
                  '11111111-1111-1111-1111-111111111111'),
  'freund'::friend_tier,
  'tier_for liefert die Einstufung, die der Besitzer vergeben hat'
);

select is(
  public.tier_for('33333333-3333-3333-3333-333333333333',
                  '44444444-4444-4444-4444-444444444444'),
  null::friend_tier,
  'Über fremde Paare gibt tier_for nichts preis'
);

select * from finish();
rollback;
