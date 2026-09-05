-- 0056: Bekommt der Melder seine Punkte — und wer darf eine vorhandene
-- Angabe ändern?
--
-- Geprüft wird in der Rolle, die es betrifft (`authenticated` mit
-- gesetztem `sub`), nicht als `postgres`: Der umgeht RLS, und Trigger
-- laufen für ihn mit `auth.uid() = null`.
--
-- **Dieser Test hat einen Entwurf umgeworfen.** Die Migration sollte
-- zuerst einen zweiten Trigger bekommen („überschreiben erst ab Stufe
-- 2"). Der Testlauf zeigte: Die Regel gibt es längst in
-- `beer_barcodes_update` (0028) — und sie ist besser, weil sie dem
-- Ersteller die Korrektur seiner eigenen Angabe lässt. Was hier steht,
-- ist deshalb die Prüfung der **vorhandenen** Regel.
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

begin;
select plan(8);

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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'neuling');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'fremder');
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'stammgast');

-- Stufe 2 per Override, statt 25 Check-ins zu erfinden.
insert into public.user_features (profile_id, feature, enabled)
values ('33333333-3333-3333-3333-333333333333', 'trust_level_2', true);

insert into public.breweries (id, name, country, city)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'Testbrauerei', 'AT', 'Wien');
insert into public.beers (id, brewery_id, name, style)
values ('bbbbbbbb-0000-0000-0000-000000000002',
        'bbbbbbbb-0000-0000-0000-000000000001', 'Testbier', 'Lager');

-- ============================================================================
-- Ein Neuling traegt eine fehlende Groesse nach
-- ============================================================================

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok($$
  insert into public.beer_barcodes (ean, beer_id, volume_ml, created_by)
  values ('90000019', 'bbbbbbbb-0000-0000-0000-000000000002', 500,
          '11111111-1111-1111-1111-111111111111')
$$, 'ein Neuling darf eine fehlende Groesse nachtragen');

select is(
  (select count(*)::int from public.edit_log
   where profile_id = '11111111-1111-1111-1111-111111111111'
     and entity = 'beer' and action = 'update'),
  1,
  'das gibt einen edit_log-Eintrag — und damit Punkte');

select is(
  (select changes ->> 'ean' from public.edit_log
   where profile_id = '11111111-1111-1111-1111-111111111111' limit 1),
  '90000019',
  'und zwar zu der gemeldeten EAN');

select is(
  (select changes -> 'volume_ml' ->> 'neu' from public.edit_log
   where profile_id = '11111111-1111-1111-1111-111111111111' limit 1),
  '500',
  'mit der neuen Groesse im Protokoll');

-- ============================================================================
-- Seinen eigenen Tippfehler darf er richtigstellen
-- ============================================================================

select lives_ok($$
  update public.beer_barcodes set volume_ml = 330 where ean = '90000019'
$$, 'die eigene Angabe darf der Melder korrigieren');

-- ============================================================================
-- Ein Fremder ohne Stufe 2 nicht
-- ============================================================================

set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

-- RLS laesst die Zeile fuer ihn nicht zu — das Update trifft null Zeilen,
-- statt einen Fehler zu werfen. Genau deshalb wird der Wert geprueft und
-- nicht nur der Aufruf.
select lives_ok($$
  update public.beer_barcodes set volume_ml = 1000 where ean = '90000019'
$$, 'der Versuch selbst laeuft ohne Fehler durch');

select is(
  (select volume_ml from public.beer_barcodes where ean = '90000019'),
  330,
  'aber er hat nichts veraendert — RLS liess die Zeile nicht zu');

-- ============================================================================
-- Ein Stammgast darf
-- ============================================================================

set local request.jwt.claims =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select lives_ok($$
  update public.beer_barcodes set volume_ml = 500 where ean = '90000019'
$$, 'ab Stufe 2 ist die fremde Korrektur erlaubt');

select * from finish();
rollback;
