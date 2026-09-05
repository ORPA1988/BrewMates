-- 0058: Die Voreinstellung für neue Check-ins.
--
-- Zwei Fragen, beide in der Rolle geprüft, die es betrifft: Steht die
-- Vorgabe richtig, und kann jemand sie bei einem **anderen** ändern?
--
-- Die dritte Frage — ob `private` wirklich verbirgt — beantwortet
-- `runden_checkins.test.sql` seit 0050. Sie wird hier nicht wiederholt.
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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'ichselbst');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'jemandanders');

-- ============================================================================
-- Die Vorgabe
-- ============================================================================

select is(
  (select default_visibility::text from public.profiles
    where id = '11111111-1111-1111-1111-111111111111'),
  'friends',
  'ohne Zutun steht die Voreinstellung auf friends');

select is(
  (select column_default from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = 'default_visibility'),
  '''friends''::visibility',
  'und zwar als Spaltenvorgabe, nicht nur zufaellig');

-- ============================================================================
-- Die Rechte auf der Spalte
--
-- Der erste Entwurf dieser Migration hatte sie vergessen: Seit 0025/0026
-- gelten auf `profiles` **Spaltenrechte**, und eine neue Spalte erbt
-- davon nichts. Ohne diese beiden Proben faellt das erst auf, wenn ein
-- Mensch die Voreinstellung nicht speichern kann.
-- ============================================================================

-- Lesen ausdruecklich NICHT: Spaltenrechte gelten pro Spalte, nicht pro
-- Zeile — ein select-Recht haette die Voreinstellung jedem Freund und
-- jedem Crew-Mitglied gezeigt (0059, dieselbe Lehre wie thirsty_until).
select ok(
  not has_column_privilege('authenticated', 'public.profiles',
                           'default_visibility', 'select'),
  'die Voreinstellung liest niemand aus der Profilzeile');

select ok(
  has_function_privilege('authenticated', 'public.my_default_visibility()',
                         'execute'),
  'ueber sich selbst erfaehrt man sie per Funktion');

select ok(
  not has_function_privilege('anon', 'public.my_default_visibility()',
                             'execute'),
  'anon nicht');

select ok(
  has_column_privilege('authenticated', 'public.profiles',
                       'default_visibility', 'update'),
  'und sie schreiben');

-- ============================================================================
-- Wer sie aendern darf
-- ============================================================================

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok($$
  update public.profiles set default_visibility = 'private'
   where id = '11111111-1111-1111-1111-111111111111'
$$, 'die eigene Voreinstellung darf man setzen');

select is(
  (select my_default_visibility()::text),
  'private',
  'und sie steht danach so da — gelesen ueber die Funktion');

-- Fremde Zeile: RLS laesst sie nicht zu, das Update trifft null Zeilen.
-- Geprueft wird deshalb der Wert, nicht der Aufruf.
update public.profiles set default_visibility = 'private'
 where id = '22222222-2222-2222-2222-222222222222';

-- Als `postgres` gelesen, nicht als der Nutzer: Der darf die Spalte
-- gar nicht mehr sehen — genau das ist der Punkt.
reset role;
select is(
  (select default_visibility::text from public.profiles
    where id = '22222222-2222-2222-2222-222222222222'),
  'friends',
  'die eines anderen bleibt unberuehrt');

select * from finish();
rollback;
