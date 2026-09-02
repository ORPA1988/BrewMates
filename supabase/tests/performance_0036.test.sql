-- Leistung (Migration 0036): auth.uid() als InitPlan, Indizes auf FKs.
--
-- Die Semantik der Policies prüfen die RLS-Tests. Hier geht es nur
-- darum, dass die Umschreibung vollständig ist und bleibt — eine neue
-- Policy mit nacktem auth.uid() fiele sonst erst dem Linter auf.
begin;
select plan(3);

select is(
  (select count(*) from pg_policies
    where schemaname = 'public'
      and (regexp_replace(coalesce(qual, ''), '\( SELECT auth\.uid\(\)', '', 'g') like '%auth.uid()%'
           or regexp_replace(coalesce(with_check, ''), '\( SELECT auth\.uid\(\)', '', 'g') like '%auth.uid()%')),
  0::bigint,
  'Keine Policy in public wertet auth.uid() noch pro Zeile aus'
);

select ok(
  (select count(*) from pg_policies
    where schemaname = 'public' and coalesce(qual, '') like '%( SELECT auth.uid()%') > 50,
  'Die Umschreibung hat die Policies tatsächlich erreicht (nicht nur leer gelaufen)'
);

select is(
  (select count(*)
     from pg_constraint c
     join pg_namespace ns on ns.oid = c.connamespace
    where c.contype = 'f' and ns.nspname = 'public'
      and not exists (
        select 1 from pg_index i
         where i.indrelid = c.conrelid
           and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey
      )),
  0::bigint,
  'Jeder Fremdschlüssel in public hat einen Index'
);

select * from finish();
rollback;
