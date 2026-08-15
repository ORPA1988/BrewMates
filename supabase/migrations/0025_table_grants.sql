-- 0025: Tabellenrechte für anon und authenticated explizit vergeben.
--
-- ============================================================================
-- WARUM DAS FEHLTE — und warum es niemandem auffiel
--
-- Das Live-Projekt gibt `anon` und `authenticated` volle DML-Rechte auf
-- allen Tabellen in `public`; begrenzt wird ausschließlich über RLS. Das
-- ist Supabases Standardmodell und war nie ein Versehen.
--
-- Diese Rechte standen aber in KEINER Migration. Sie stammen aus den
-- Default-Privileges, die Supabase beim Anlegen des Projekts setzt und
-- die greifen, wenn Tabellen über den SQL-Editor entstehen. Baut man die
-- Datenbank dagegen allein aus `supabase/migrations/` auf, greifen sie
-- nicht — die Tabellen kommen dann mit REFERENCES/TRIGGER/TRUNCATE hoch,
-- ohne SELECT, INSERT, UPDATE, DELETE.
--
-- Folge: Das Repo konnte das Projekt nicht wiederherstellen. Ein
-- Neuaufbau, eine Staging-Umgebung oder ein Preview-Branch wäre mit einer
-- App hochgekommen, die nichts lesen und nichts schreiben darf. Aufgefallen
-- ist es erst, als für die RLS-Tests (Backlog A-2) zum ersten Mal eine
-- Datenbank wirklich from scratch gebaut wurde — vorher hatte niemand den
-- Aufbauweg getestet, nur den gewachsenen Zustand.
--
-- Auf dem Live-Projekt ändert diese Migration nichts; sie schreibt fest,
-- was dort ohnehin gilt.
--
-- ============================================================================
-- REIHENFOLGE: Diese Migration MUSS vor 0026 laufen.
--
-- `grant select on <tabelle>` gilt für ALLE Spalten und hebt einen
-- vorherigen spaltenweisen Entzug stillschweigend wieder auf. Stünde sie
-- nach 0026, wäre `profiles.thirsty_until` wieder frei lesbar — ohne
-- Fehlermeldung, ohne dass es jemand merkt. Deshalb erst die Fläche
-- vergeben, dann in 0026 die eine Spalte herausnehmen.
-- ============================================================================

-- Nur Tabellen, die uns gehören: `spatial_ref_sys` gehört PostGIS und ist
-- als bekannte Ausnahme dokumentiert (Security-Advisor-Baseline). Ein
-- pauschales `on all tables in schema public` würde daran scheitern.
do $$
declare t record;
begin
  for t in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and pg_get_userbyid(c.relowner) = current_user
  loop
    execute format(
      'grant select, insert, update, delete on public.%I to anon, authenticated',
      t.relname);
  end loop;
end $$;

do $$
declare s record;
begin
  for s in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'S'
      and pg_get_userbyid(c.relowner) = current_user
  loop
    execute format('grant usage, select on sequence public.%I to anon, authenticated',
                   s.relname);
  end loop;
end $$;

-- Damit künftige Tabellen nicht wieder rechtelos hochkommen. Genau diese
-- Lücke hat den Aufbauweg jahrelang unbemerkt kaputt gehalten.
alter default privileges in schema public
  grant select, insert, update, delete on tables to anon, authenticated;
alter default privileges in schema public
  grant usage, select on sequences to anon, authenticated;

-- Hinweis: Für FUNKTIONEN gilt weiterhin das Gegenteil (seit 0008) —
-- EXECUTE wird von PUBLIC entzogen und pro Funktion gezielt gewährt. Bei
-- Tabellen ist RLS die Schranke, bei Funktionen das Recht selbst.
