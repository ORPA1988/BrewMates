-- Sicherheits-Härtung 0035: Unangemeldete schreiben nie, Fotos haben
-- Grenzen, eigene Fotos lassen sich löschen.
begin;
select plan(6);

-- 1. anon hat auf keiner eigenen Tabelle in public ein Schreibrecht mehr.
--    Gezaehlt werden nur Objekte, die `postgres` gehoeren: PostGIS
--    (spatial_ref_sys, geometry_columns, geography_columns) gehoert
--    supabase_admin, dort wirkt kein REVOKE — bekannte Baseline.
select is(
  (select count(*)
     from information_schema.table_privileges tp
     join pg_class c on c.relname = tp.table_name
     join pg_namespace n on n.oid = c.relnamespace and n.nspname = tp.table_schema
    where tp.grantee = 'anon' and tp.table_schema = 'public'
      and tp.privilege_type in ('INSERT', 'UPDATE', 'DELETE')
      and pg_get_userbyid(c.relowner) <> 'supabase_admin'),
  0::bigint,
  'anon hat keinerlei INSERT/UPDATE/DELETE auf eigenen public-Tabellen'
);

-- … und auch nicht auf Tabellen, die künftig dazukommen.
create table public.zzz_probe (id int);
select is(
  (select count(*) from information_schema.table_privileges
    where grantee = 'anon' and table_schema = 'public' and table_name = 'zzz_probe'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0::bigint,
  'Default-Privileges geben anon auf neuen Tabellen kein Schreibrecht'
);
drop table public.zzz_probe;

-- Die Regel muss auch praktisch greifen: anon läuft in 42501, nicht in RLS.
set local role anon;
select throws_ok(
  $$ insert into public.venues (name, category) values ('Probe', 'gasthaus') $$,
  '42501',
  null,
  'anon scheitert schon am Tabellenrecht, nicht erst an RLS'
);
reset role;

-- 2. Bucket-Grenzen.
select is(
  (select file_size_limit from storage.buckets where id = 'beer-photos'),
  5242880::bigint,
  'beer-photos ist auf 5 MB begrenzt'
);
select ok(
  (select allowed_mime_types @> array['image/jpeg']
      and not (allowed_mime_types @> array['application/octet-stream'])
     from storage.buckets where id = 'beer-photos'),
  'beer-photos nimmt nur Bilder'
);

-- 3. Delete-Policy vorhanden.
select is(
  (select count(*) from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'beer_photos_delete' and cmd = 'DELETE'),
  1::bigint,
  'Eigene Fotos dürfen gelöscht werden'
);

select * from finish();
rollback;
