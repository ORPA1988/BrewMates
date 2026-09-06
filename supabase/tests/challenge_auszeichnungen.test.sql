-- Vier Auszeichnungen je Challenge (0063).
--
-- Die interessanten Regeln sind nicht „wer gewinnt", sondern die drei
-- Entscheidungen, die man beim Lesen des Codes leicht wieder herausnimmt:
--
--   1. Es gibt genau EINEN Ersten und EINEN Letzten — erzwungen von einem
--      Teilindex, nicht von der Anwendung.
--   2. Schlusslicht erst ab zwei Abschlüssen. Bei einem einzigen wäre
--      derselbe Mensch Erster und Letzter, und das liest sich wie Spott.
--   3. Kein Client darf auszeichnen. Sonst behauptet jeder, Erster zu sein.
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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'erster');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'zweiter');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'dritter');
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'allein');

-- Eine beendete und eine einsame Challenge.
insert into public.challenges (id, title, description, emoji, rule,
                               starts_at, ends_at)
values
  ('aa000000-0000-0000-0000-000000000001', 'Vorbei', 'x', 'X',
   '{"type":"checkins_count","threshold":1}'::jsonb,
   now() - interval '30 days', now() - interval '1 day'),
  ('aa000000-0000-0000-0000-000000000002', 'Einsam', 'x', 'X',
   '{"type":"checkins_count","threshold":1}'::jsonb,
   now() - interval '30 days', now() - interval '1 day');

-- --------------------------------------------------------------------------
-- 1-3: Der Trigger vergibt sofort, was sofort feststeht.
-- --------------------------------------------------------------------------
insert into public.challenge_completions (challenge_id, profile_id,
                                          completed_at)
values ('aa000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111', now() - interval '10 days');

select is(
  (select count(*)::int from public.challenge_awards
   where challenge_id = 'aa000000-0000-0000-0000-000000000001'
     and profile_id = '11111111-1111-1111-1111-111111111111'
     and kind = 'dabei'),
  1, 'Wer abschließt, bekommt sofort „dabei"');

select is(
  (select count(*)::int from public.challenge_awards
   where challenge_id = 'aa000000-0000-0000-0000-000000000001'
     and kind = 'blitzschluck'),
  1, 'Der erste Abschluss bekommt den Blitzschluck');

insert into public.challenge_completions (challenge_id, profile_id,
                                          completed_at)
values
  ('aa000000-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', now() - interval '5 days'),
  ('aa000000-0000-0000-0000-000000000001',
   '33333333-3333-3333-3333-333333333333', now() - interval '2 days');

select is(
  (select profile_id from public.challenge_awards
   where challenge_id = 'aa000000-0000-0000-0000-000000000001'
     and kind = 'blitzschluck'),
  '11111111-1111-1111-1111-111111111111'::uuid,
  'Ein zweiter Abschluss macht keinen zweiten Ersten');

-- --------------------------------------------------------------------------
-- 4-6: Nachgereicht wird erst nach dem Ende — und nur, wenn es einen
--      echten Letzten gibt.
-- --------------------------------------------------------------------------
insert into public.challenge_completions (challenge_id, profile_id,
                                          completed_at)
values ('aa000000-0000-0000-0000-000000000002',
        '44444444-4444-4444-4444-444444444444', now() - interval '3 days');

select ok(
  (select public.finalisiere_challenges()) >= 2,
  'Finalisieren läuft über beide beendeten Challenges');

select is(
  (select profile_id from public.challenge_awards
   where challenge_id = 'aa000000-0000-0000-0000-000000000001'
     and kind = 'schlusslicht'),
  '33333333-3333-3333-3333-333333333333'::uuid,
  'Schlusslicht ist der zuletzt Fertiggewordene');

select is(
  (select count(*)::int from public.challenge_awards
   where challenge_id = 'aa000000-0000-0000-0000-000000000002'
     and kind = 'schlusslicht'),
  0, 'Bei einem einzigen Finisher gibt es kein Schlusslicht');

-- --------------------------------------------------------------------------
-- 7-8: Beste Crew braucht mindestens zwei abschließende Mitglieder.
-- --------------------------------------------------------------------------
insert into public.crews (id, name, emoji, owner_id)
values
  ('bb000000-0000-0000-0000-000000000001', 'Zweierbande', '🍻',
   '11111111-1111-1111-1111-111111111111'),
  ('bb000000-0000-0000-0000-000000000002', 'Einzelkämpfer', '🍺',
   '33333333-3333-3333-3333-333333333333');
insert into public.crew_members (crew_id, profile_id)
values
  ('bb000000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111'),
  ('bb000000-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222'),
  ('bb000000-0000-0000-0000-000000000002',
   '33333333-3333-3333-3333-333333333333')
on conflict do nothing;

-- Die Auszeichnungen der ersten Challenge zurücksetzen, damit
-- finalisiere_challenges() sie mit den Crews noch einmal ansieht.
delete from public.challenge_awards
 where challenge_id = 'aa000000-0000-0000-0000-000000000001'
   and kind in ('schlusslicht', 'beste_crew');
select public.finalisiere_challenges();

select is(
  (select count(*)::int from public.challenge_awards
   where challenge_id = 'aa000000-0000-0000-0000-000000000001'
     and kind = 'beste_crew'
     and crew_id = 'bb000000-0000-0000-0000-000000000001'),
  2, 'Beide Mitglieder der besten Crew werden ausgezeichnet');

select is(
  (select count(*)::int from public.challenge_awards
   where challenge_id = 'aa000000-0000-0000-0000-000000000001'
     and kind = 'beste_crew'
     and crew_id = 'bb000000-0000-0000-0000-000000000002'),
  0, 'Eine Crew mit einem einzigen Finisher ist keine beste Crew');

-- --------------------------------------------------------------------------
-- 9-11: Rechte. Geprüft in der Rolle, die sie betrifft — `postgres` umgeht
--       RLS und beweist nichts (CLAUDE.md, Regel B).
-- --------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select throws_ok(
  $$insert into public.challenge_awards (challenge_id, profile_id, kind)
    values ('aa000000-0000-0000-0000-000000000001',
            '22222222-2222-2222-2222-222222222222', 'blitzschluck')$$,
  '42501',
  null,
  'Ein Client kann sich nicht selbst zum Ersten erklären');

select is(
  (select count(*)::int from public.challenge_awards
   where profile_id = '22222222-2222-2222-2222-222222222222'),
  2, 'Die eigenen Auszeichnungen sind lesbar (dabei + beste Crew)');

select is(
  (select count(*)::int from public.challenge_awards
   where profile_id = '44444444-4444-4444-4444-444444444444'),
  0, 'Auszeichnungen Fremder bleiben unsichtbar');

select * from finish();
rollback;
