-- 0055: Nimmt die Datenbank eine Verkaufseinheit als Trinkmenge an?
--
-- Der Anlass steht im Kopf der Migration: Open Food Facts liefert zu
-- manchen EANs die Menge des Tragerls (3000 ml). Als Füllmenge eines
-- Check-ins wäre das falsch, und die Regel dagegen gehört an den Server
-- — eine Grenze, die nur die App kennt, umgeht der nächste Client.
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

begin;
select plan(5);

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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'pfleger');

insert into public.breweries (id, name, country, city)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'Testbrauerei', 'AT', 'Wien');

insert into public.beers (id, brewery_id, name, style)
values ('bbbbbbbb-0000-0000-0000-000000000002',
        'bbbbbbbb-0000-0000-0000-000000000001', 'Testbier', 'Lager');

-- Eine Einzelflasche geht durch.
select lives_ok($$
  insert into public.beer_barcodes (ean, beer_id, volume_ml)
  values ('90000019', 'bbbbbbbb-0000-0000-0000-000000000002', 500)
$$, '0,5 l wird angenommen');

-- Ein Sixpack nicht.
select throws_ok($$
  insert into public.beer_barcodes (ean, beer_id, volume_ml)
  values ('90000026', 'bbbbbbbb-0000-0000-0000-000000000002', 3000)
$$, '23514', null,
   'ein 6er-Tragerl mit 3000 ml wird abgelehnt');

-- Auch knapp darueber nicht.
select throws_ok($$
  insert into public.beer_barcodes (ean, beer_id, volume_ml)
  values ('90000033', 'bbbbbbbb-0000-0000-0000-000000000002', 1001)
$$, '23514', null,
   'ueber einem Liter ist es keine Trinkmenge mehr');

-- Ein Growler mit genau einem Liter schon.
select lives_ok($$
  insert into public.beer_barcodes (ean, beer_id, volume_ml)
  values ('90000040', 'bbbbbbbb-0000-0000-0000-000000000002', 1000)
$$, 'genau 1 l geht — so viel bietet die App an');

-- Und „unbekannt" bleibt erlaubt: Eine EAN ohne Groesse ist kein Fehler.
select lives_ok($$
  insert into public.beer_barcodes (ean, beer_id, volume_ml)
  values ('90000057', 'bbbbbbbb-0000-0000-0000-000000000002', null)
$$, 'ohne Angabe bleibt erlaubt');

select * from finish();
rollback;
