-- 0045: TRUNCATE, REFERENCES und TRIGGER für anon und authenticated entziehen.
--
-- ============================================================================
-- DER BEFUND
--
-- Aufgefallen beim Gegenprüfen von 0044: `crew_invites` kam mit den
-- Rechten `REFERENCES, SELECT, TRIGGER, TRUNCATE` für `anon` hoch — und
-- jede andere Tabelle in `public` hat dieselben. 0035 hatte nur
-- INSERT/UPDATE/DELETE entzogen; die drei übrigen stammen aus den
-- Default-Privileges, die Supabase beim Anlegen des Projekts setzt, und
-- 0025 nennt sie sogar beiläufig („die Tabellen kommen dann mit
-- REFERENCES/TRIGGER/TRUNCATE hoch") — ohne die Folge zu ziehen.
--
-- **TRUNCATE ist der ernste Teil: Es umgeht RLS.** Kein `using`, kein
-- `with check` wird gefragt; wer das Recht hat, leert die Tabelle. Die
-- Sicherheit von BrewMates hängt an RLS — ein Recht, das darum
-- herumführt, gehört niemandem, der es nicht braucht.
--
-- **Offen war es nicht.** PostgREST bietet kein TRUNCATE an; über die
-- API gibt es keinen Weg dorthin, und `anon`/`authenticated` haben keinen
-- eigenen Datenbankzugang. Das ist der Grund, warum es zwei Sicherheits-
-- Checks lang durchgerutscht ist: Es war nie eine offene Tür, immer nur
-- ein Schlüssel, der bei jemandem lag, der ihn nicht braucht.
--
-- TRIGGER und REFERENCES kommen mit, aus demselben Grund: TRIGGER erlaubt
-- es, eigenen Code an eine fremde Tabelle zu hängen, REFERENCES eigene
-- Fremdschlüssel darauf. Beides braucht die App nie — sie spricht
-- ausschließlich über PostgREST.
--
-- SELECT bleibt. Unangemeldete sollen lesen dürfen (Biere, Brauereien,
-- öffentliche Check-ins); begrenzt wird das über RLS, wie in 0025
-- festgelegt.
--
-- ============================================================================
-- WAS DIESE MIGRATION NICHT KANN
--
-- `spatial_ref_sys`, `geometry_columns`, `geography_columns` gehören
-- PostGIS bzw. `supabase_admin`. Der Schleifendurchlauf unten fasst nur
-- Tabellen an, die `current_user` gehören — dieselbe Einschränkung wie in
-- 0025, aus demselben Grund: Ein REVOKE als `postgres` läuft dort durch
-- und ändert nichts. Bleibt dokumentierte Baseline.
-- ============================================================================

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
      'revoke truncate, references, trigger on public.%I from anon, authenticated',
      t.relname);
  end loop;
end $$;

-- Und damit die nächste Tabelle nicht wieder damit hochkommt. Genau das
-- ist bei `crew_invites` passiert, obwohl 0035 acht Monate vorher lief.
alter default privileges in schema public
  revoke truncate, references, trigger on tables from anon, authenticated;
