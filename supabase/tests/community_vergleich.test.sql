-- Community-Vergleich (0054): Gibt die Funktion Zahlen heraus, die
-- niemanden verraten?
--
-- Die interessante Regel ist nicht der Durchschnitt, sondern die
-- Schwelle: Unter 20 beitragenden Personen ist ein Mittelwert keine
-- Statistik, sondern eine Auskunft über die wenigen. Wer die Schwelle
-- senkt, muss an diesem Test vorbei.
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

begin;
select plan(7);

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

-- Der Fragende und drei andere.
select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'ich');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'a');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'b');
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'c');

insert into public.checkins (id, profile_id, beer_name, visibility, created_at)
values
  -- eigene: zählen nie mit
  ('cc000000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'Mein Bier', 'friends', now()),
  ('cc000000-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111', 'Mein Bier', 'friends', now()),
  -- drei andere, einer davon zweimal
  ('cc000000-0000-0000-0000-000000000003',
   '22222222-2222-2222-2222-222222222222', 'Bier A', 'friends', now()),
  ('cc000000-0000-0000-0000-000000000004',
   '22222222-2222-2222-2222-222222222222', 'Bier B', 'friends', now()),
  ('cc000000-0000-0000-0000-000000000005',
   '33333333-3333-3333-3333-333333333333', 'Bier A', 'friends', now()),
  ('cc000000-0000-0000-0000-000000000006',
   '44444444-4444-4444-4444-444444444444', 'Bier A', 'private', now());

-- ============================================================================
-- Rechte
-- ============================================================================

select ok(
  has_function_privilege('authenticated',
    'public.community_stats(timestamptz, timestamptz)', 'execute'),
  'authenticated darf community_stats aufrufen');

select ok(
  not has_function_privilege('anon',
    'public.community_stats(timestamptz, timestamptz)', 'execute'),
  'anon darf nicht — die Zahlen sind fuer Angemeldete');

-- ============================================================================
-- Die Schwelle
-- ============================================================================

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  (select teilnehmer from public.community_stats(
     now() - interval '1 day', now() + interval '1 day')),
  3,
  'zaehlt die drei anderen, nicht mich selbst');

select is(
  (select schnitt_checkins from public.community_stats(
     now() - interval '1 day', now() + interval '1 day')),
  null,
  'unter der Schwelle bleibt der Durchschnitt leer');

select is(
  (select schnitt_biere from public.community_stats(
     now() - interval '1 day', now() + interval '1 day')),
  null,
  'auch die Bier-Vielfalt bleibt leer');

-- ============================================================================
-- Zeitraum und leere Menge
-- ============================================================================

select is(
  (select teilnehmer from public.community_stats(
     now() - interval '30 day', now() - interval '20 day')),
  0,
  'ausserhalb des Zeitraums traegt niemand bei');

select is(
  (select schnitt_checkins from public.community_stats(
     now() - interval '30 day', now() - interval '20 day')),
  null,
  'und ohne Beitraege gibt es auch keinen Durchschnitt');

select * from finish();
rollback;
