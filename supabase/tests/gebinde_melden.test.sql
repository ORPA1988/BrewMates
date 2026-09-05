-- 0056: Bekommt der Melder seine Punkte, und ist eine geprüfte Angabe
-- vor einem Fehltipp sicher?
--
-- Geprüft wird in der Rolle, die es betrifft (`authenticated` mit
-- gesetztem `sub`), nicht als `postgres` — der umgeht RLS und Trigger
-- laufen für ihn mit `auth.uid() = null`.
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
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'stammgast');

-- Stufe 2 per Override, statt 25 Check-ins zu erfinden.
insert into public.user_features (profile_id, feature, enabled)
values ('22222222-2222-2222-2222-222222222222', 'trust_level_2', true);

insert into public.breweries (id, name, country, city)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'Testbrauerei', 'AT', 'Wien');
insert into public.beers (id, brewery_id, name, style)
values ('bbbbbbbb-0000-0000-0000-000000000002',
        'bbbbbbbb-0000-0000-0000-000000000001', 'Testbier', 'Lager');

-- ============================================================================
-- Ein Neuling fuellt eine leere Angabe
-- ============================================================================

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok($$
  insert into public.beer_barcodes (ean, beer_id, volume_ml)
  values ('90000019', 'bbbbbbbb-0000-0000-0000-000000000002', 500)
$$, 'ein Neuling darf eine fehlende Groesse nachtragen');

select is(
  (select count(*)::int from public.edit_log
   where profile_id = '11111111-1111-1111-1111-111111111111'
     and entity = 'beer' and action = 'update'),
  1,
  'das gibt einen edit_log-Eintrag — und damit Punkte');

select is(
  (select changes -> 'ean' ->> 0 from public.edit_log
   where profile_id = '11111111-1111-1111-1111-111111111111' limit 1),
  null,
  'die EAN steht als Wert, nicht als Liste');

select is(
  (select changes ->> 'ean' from public.edit_log
   where profile_id = '11111111-1111-1111-1111-111111111111' limit 1),
  '90000019',
  'und zwar die gemeldete');

-- ============================================================================
-- Derselbe Neuling darf sie nicht wieder aendern
-- ============================================================================

select throws_ok($$
  update public.beer_barcodes set volume_ml = 330 where ean = '90000019'
$$, '42501', null,
   'eine vorhandene Groesse aendert ein Neuling nicht');

select is(
  (select volume_ml from public.beer_barcodes where ean = '90000019'),
  500,
  'der geprellte Versuch hat nichts veraendert');

-- ============================================================================
-- Ein Stammgast darf
-- ============================================================================

set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select lives_ok($$
  update public.beer_barcodes set volume_ml = 330 where ean = '90000019'
$$, 'ab Stufe 2 ist die Korrektur erlaubt');

select is(
  (select count(*)::int from public.edit_log
   where profile_id = '22222222-2222-2222-2222-222222222222'
     and entity = 'beer' and action = 'update'),
  1,
  'und wird ebenfalls protokolliert');

select * from finish();
rollback;
