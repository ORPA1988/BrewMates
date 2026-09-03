-- Sprechbarer Einladungscode (Migration 0041).
--
-- Der Beitritt läuft über eine Funktion, weil `crews_select` nur die
-- eigenen Crews zeigt — der Client kann „welche Crew hat Code X?" gar
-- nicht fragen. Genau darum muss die Funktion eng sein: Sie darf
-- eintragen und sonst nichts verraten.

begin;
select plan(15);

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

set local role postgres;
insert into public.crews (id, name, owner_id)
values ('c0000000-0000-0000-0000-000000000001', 'Stammtisch',
        '11111111-1111-1111-1111-111111111111');
insert into public.crew_members (crew_id, profile_id)
values ('c0000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111');

-- ============================================================================
-- Der Code selbst
--
-- Der wichtigste Test steht weiter unten: dass eine Crew sich auch als
-- `authenticated` anlegen laesst. 0041 hatte den Code per Spaltenvorgabe
-- erzeugt — und die wird mit den Rechten des Einfuegenden ausgewertet,
-- nicht mit denen des Besitzers. „Crew gruenden" scheiterte deshalb in
-- der App, waehrend jede Pruefung als `postgres` gruen war.
-- ============================================================================

select is(
  (select length(join_code) from public.crews
    where id = 'c0000000-0000-0000-0000-000000000001'),
  6,
  'Eine neue Crew bekommt ihren Code von selbst'
);

select ok(
  (select join_code !~ '[OIL01]' from public.crews
    where id = 'c0000000-0000-0000-0000-000000000001'),
  'Keine Zwillinge im Alphabet — Vorgelesenes soll ankommen'
);

select ok(
  (select join_code ~ '^[A-Z2-9]{6}$' from public.crews
    where id = 'c0000000-0000-0000-0000-000000000001'),
  'Nur Großbuchstaben und Ziffern'
);

-- Zwei Crews, zwei Codes.
insert into public.crews (id, name, owner_id)
values ('c0000000-0000-0000-0000-000000000002', 'Verein',
        '11111111-1111-1111-1111-111111111111');

-- Die Codes festhalten, solange wir sie noch sehen: Gleich prueft der
-- Test aus der Sicht von Bert, und der sieht die Crews nicht — das ist
-- ja gerade der Grund fuer die Funktion.
create temporary table codes as
select id, join_code from public.crews;
-- Die Tabelle gehoert `postgres`; gleich prueft der Test als
-- `authenticated`, und der duerfte sonst nicht hineinsehen.
grant select on codes to authenticated;

select isnt(
  (select join_code from public.crews
    where id = 'c0000000-0000-0000-0000-000000000001'),
  (select join_code from public.crews
    where id = 'c0000000-0000-0000-0000-000000000002'),
  'Zwei Crews haben nie denselben Code'
);

-- ============================================================================
-- Beitreten
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

-- Bert sieht die Crew vorher nicht — genau deshalb braucht es die Funktion.
select is(
  (select count(*) from public.crews),
  0::bigint,
  'Fremde Crews sind unsichtbar, auch mit Code in der Hand'
);

select is(
  public.join_crew_by_code(
    (select join_code from codes
      where id = 'c0000000-0000-0000-0000-000000000001')),
  'c0000000-0000-0000-0000-000000000001'::uuid,
  'Mit dem richtigen Code tritt man bei'
);

select is(
  (select count(*) from public.crews),
  1::bigint,
  'Und sieht die Crew danach'
);

-- Schreibweise verzeihen: klein getippt, mit Bindestrich.
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  public.join_crew_by_code(
    lower((select join_code from codes
            where id = 'c0000000-0000-0000-0000-000000000002'))),
  'c0000000-0000-0000-0000-000000000002'::uuid,
  'Klein getippt ist derselbe Code'
);

-- ============================================================================
-- Was der Code NICHT verrät
-- ============================================================================

select is(
  public.join_crew_by_code('ZZZZZZ'),
  null::uuid,
  'Ein unbekannter Code führt nirgendwohin'
);

select is(
  public.join_crew_by_code(null),
  null::uuid,
  'Und nichts ist auch kein Code'
);

-- ============================================================================
-- Eine Crew anlegen — in der Rolle, die es tatsaechlich tut
--
-- Das ist der Test, der 0041 gefunden haette. Er prueft nicht, dass der
-- Code richtig AUSSIEHT, sondern dass ihn der richtige Rolleninhaber
-- ueberhaupt bekommt.
-- ============================================================================

select lives_ok(
  $$insert into public.crews (id, name, owner_id)
    values ('c0000000-0000-0000-0000-000000000009', 'Aus der App',
            '11111111-1111-1111-1111-111111111111')$$,
  'Ein angemeldeter Nutzer kann eine Crew anlegen'
);

-- Der Test, der 0043 gefunden haette: Die App liest die neue ID mit
-- `returning` zurueck. Das verlangt zusaetzlich die SELECT-Regel — und
-- die verlangte eine Mitgliedschaft, die es in diesem Augenblick noch
-- nicht geben kann. „Crew gruenden" scheiterte deshalb seit 0.9.12.
select lives_ok(
  $$insert into public.crews (id, name, owner_id)
    values ('c0000000-0000-0000-0000-00000000000a', 'Mit Rueckgabe',
            '11111111-1111-1111-1111-111111111111')
    returning id$$,
  'Und die neue ID gleich zurueckgelesen — Henne und Ei'
);

select is(
  (select count(*) from public.crews
    where id = 'c0000000-0000-0000-0000-00000000000a'),
  1::bigint,
  'Der Gruender sieht seine Crew, bevor er Mitglied ist'
);

-- Die Grenze bleibt: fremde Crews sind weiterhin unsichtbar.
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
select is(
  (select count(*) from public.crews
    where id = 'c0000000-0000-0000-0000-00000000000a'),
  0::bigint,
  'Ein Fremder sieht sie deshalb noch lange nicht'
);

set local role postgres;
select ok(
  (select join_code ~ '^[A-Z2-9]{6}$' from public.crews
    where id = 'c0000000-0000-0000-0000-000000000009'),
  'Und sie bekommt dabei ihren Code'
);

select * from finish();
rollback;
