-- 0036: Leistung — auth.uid() einmal pro Abfrage, Indizes auf Fremdschlüssel.
--
-- ============================================================================
-- WAS
--
-- 1. In jeder RLS-Policy stand `auth.uid()`. Postgres wertet das für **jede
--    geprüfte Zeile** neu aus. `(select auth.uid())` wird als InitPlan
--    **einmal pro Abfrage** berechnet — inhaltlich identisch, nur die
--    Auswertung ändert sich. (Linter: auth_rls_initplan, 77 Policies.)
--
-- 2. 21 Fremdschlüssel hatten keinen Index. Beim Löschen einer Zeile, auf
--    die verwiesen wird, und bei „alle X zu diesem Y" liest Postgres sonst
--    die ganze Tabelle. (Linter: unindexed_foreign_keys.)
--
-- ============================================================================
-- WIE — aus dem Katalog, nicht abgetippt
--
-- 77 Policies von Hand umzuschreiben wären 77 Stellen für einen Tippfehler
-- in einer Sicherheitsregel. Deshalb liest dieser Block die Policies aus
-- `pg_policies`, ersetzt textuell `auth.uid()` durch `(select auth.uid())`
-- und legt sie per ALTER POLICY zurück. Das ist idempotent (bereits
-- umgeschriebene Policies enthalten `( SELECT auth.uid()` und werden
-- übersprungen) und funktioniert im From-scratch-Aufbau der CI genauso
-- wie live. Die bestehenden RLS-Tests prüfen danach die **Semantik** —
-- sie müssen unverändert grün sein.
--
-- Die Indizes ebenso: Jeder Fremdschlüssel in `public`, dessen Spalten
-- nicht bereits ein Index als Präfix abdeckt, bekommt einen.
-- ============================================================================

-- 1. Policies
do $$
declare
  p record;
  v_using text;
  v_check text;
  n int := 0;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
      from pg_policies
     where schemaname = 'public'
       and (coalesce(qual, '') like '%auth.uid()%'
            or coalesce(with_check, '') like '%auth.uid()%')
       and coalesce(qual, '') not like '%( SELECT auth.uid()%'
       and coalesce(with_check, '') not like '%( SELECT auth.uid()%'
  loop
    v_using := case when p.qual is not null
      then ' using (' || replace(p.qual, 'auth.uid()', '(select auth.uid())') || ')' else '' end;
    v_check := case when p.with_check is not null
      then ' with check (' || replace(p.with_check, 'auth.uid()', '(select auth.uid())') || ')' else '' end;
    execute format('alter policy %I on %I.%I%s%s',
                   p.policyname, p.schemaname, p.tablename, v_using, v_check);
    n := n + 1;
  end loop;
  raise notice '0036: % Policies umgeschrieben', n;
end $$;

-- 2. Indizes auf Fremdschlüssel
do $$
declare
  fk record;
  n int := 0;
begin
  for fk in
    select c.conrelid::regclass as tbl,
           (select string_agg(a.attname, ', ' order by k.ord)
              from unnest(c.conkey) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum) as cols,
           (select string_agg(a.attname, '_' order by k.ord)
              from unnest(c.conkey) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum) as colname
      from pg_constraint c
      join pg_namespace ns on ns.oid = c.connamespace
     where c.contype = 'f' and ns.nspname = 'public'
       and not exists (
         select 1 from pg_index i
          where i.indrelid = c.conrelid
            and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey
       )
  loop
    execute format('create index if not exists %I on %s (%s)',
                   replace(fk.tbl::text, 'public.', '') || '_' || fk.colname || '_idx',
                   fk.tbl, fk.cols);
    n := n + 1;
  end loop;
  raise notice '0036: % Indizes angelegt', n;
end $$;
