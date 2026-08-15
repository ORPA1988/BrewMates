-- Barcodes je Bier mit Gebindegröße (Migration 0028).
--
-- Der fachliche Kern: Eine EAN bezeichnet die **Handelseinheit**, nicht
-- das Getränk. Ein Bier hat deshalb mehrere Codes, und die Größe gehört
-- an den Code.
--
-- Der gefährlichste Fehler hier ist eine falsche Zuordnung: Ein Code, der
-- auf das falsche Bier zeigt, schickt jeden Scanner dorthin. Deshalb darf
-- nicht jeder frisch Registrierte fremde Zuordnungen umbiegen.

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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'anna');
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'bert');

insert into public.breweries (id, name, country, city)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'Testbrauerei', 'AT', 'Wien');

insert into public.beers (id, brewery_id, name, style, created_by)
values
  ('beee0001-0000-0000-0000-000000000001',
   'bbbbbbbb-0000-0000-0000-000000000001', 'Testbier', 'Märzen',
   '11111111-1111-1111-1111-111111111111'),
  ('beee0002-0000-0000-0000-000000000002',
   'bbbbbbbb-0000-0000-0000-000000000001', 'Anderes Bier', 'Pils',
   '11111111-1111-1111-1111-111111111111');

-- ============================================================================
-- Als anna
-- ============================================================================
set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$insert into public.beer_barcodes (ean, beer_id, volume_ml, created_by)
    values ('90034107', 'beee0001-0000-0000-0000-000000000001', 330,
            '11111111-1111-1111-1111-111111111111')$$,
  'Angemeldete dürfen einen Barcode nachtragen'
);

select lives_ok(
  $$insert into public.beer_barcodes (ean, beer_id, volume_ml, created_by)
    values ('90034558', 'beee0001-0000-0000-0000-000000000001', 500,
            '11111111-1111-1111-1111-111111111111')$$,
  'Ein zweiter Code für dasselbe Bier ist der Normalfall, kein Konflikt'
);

select is(
  (select count(*)::int from public.beer_barcodes
    where beer_id = 'beee0001-0000-0000-0000-000000000001'),
  2,
  'Ein Bier trägt mehrere Codes — genau das konnte beers.barcode nicht'
);

select is(
  (select volume_ml from public.beer_barcodes where ean = '90034107'),
  330,
  'Die Größe hängt am Code: 0,33 …'
);

select is(
  (select volume_ml from public.beer_barcodes where ean = '90034558'),
  500,
  '… und derselbe Artikel als 0,5 hat eine eigene Nummer'
);

-- Ein Code kann nur zu EINEM Bier gehören; sonst führe der Scan ins Leere.
select throws_ok(
  $$insert into public.beer_barcodes (ean, beer_id, created_by)
    values ('90034107', 'beee0002-0000-0000-0000-000000000002',
            '11111111-1111-1111-1111-111111111111')$$,
  '23505',
  null,
  'Derselbe Code an zwei Bieren wird abgelehnt'
);

select throws_ok(
  $$insert into public.beer_barcodes (ean, beer_id, created_by)
    values ('12345', 'beee0001-0000-0000-0000-000000000001',
            '11111111-1111-1111-1111-111111111111')$$,
  '23514',
  null,
  'Was keine 8 oder 13 Ziffern hat, ist kein Barcode'
);

-- ============================================================================
-- Als bert (Neuling, Stufe 1, nicht der Ersteller)
-- ============================================================================
set local "request.jwt.claims" =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is(
  (select count(*)::int from public.beer_barcodes),
  2,
  'Lesen darf jeder Angemeldete — ein Barcode steht auf der Flasche'
);

-- Die Zuordnung eines Fremden umzubiegen ist der teuerste Fehler hier:
-- Der Scan landete danach beim falschen Bier.
update public.beer_barcodes
   set beer_id = 'beee0002-0000-0000-0000-000000000002'
 where ean = '90034107';

select is(
  (select beer_id from public.beer_barcodes where ean = '90034107'),
  'beee0001-0000-0000-0000-000000000001'::uuid,
  'Ein Neuling biegt fremde Zuordnungen nicht um (RLS greift still)'
);

select * from finish();
rollback;
