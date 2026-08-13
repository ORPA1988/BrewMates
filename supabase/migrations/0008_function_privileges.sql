-- Function-Härtung: Postgres gewährt EXECUTE auf neue Funktionen automatisch
-- an PUBLIC – davon erben anon UND authenticated, weshalb die bisherigen
-- „revoke … from anon"-Aufrufe (0005/0006/0007) ins Leere liefen (Linter-Regel
-- 0028). Deshalb hier: EXECUTE grundsätzlich von PUBLIC entziehen und nur den
-- Rollen zurückgeben, die die jeweilige Funktion wirklich brauchen.

-- RLS-Hilfsfunktionen: laufen in Policies im Kontext des anfragenden Nutzers,
-- angemeldete Nutzer brauchen also EXECUTE – anon nicht.
revoke execute on function public.are_friends(uuid, uuid) from public, anon;
grant execute on function public.are_friends(uuid, uuid) to authenticated;

revoke execute on function public.is_crew_member(uuid, uuid) from public, anon;
grant execute on function public.is_crew_member(uuid, uuid) to authenticated;

revoke execute on function public.is_admin(uuid) from public, anon;
grant execute on function public.is_admin(uuid) to authenticated;

-- Karten-Zähler: nur für Angemeldete (anon bekäme ohnehin immer 0, weil
-- auth.uid() dann NULL ist – aber der Endpunkt soll gar nicht offen sein).
revoke execute on function public.count_other_active_sessions(
  double precision, double precision, double precision, double precision
) from public, anon;
grant execute on function public.count_other_active_sessions(
  double precision, double precision, double precision, double precision
) to authenticated;

-- Wartungs- und Trigger-Funktionen: kein Client ruft sie direkt auf.
-- pg_cron läuft als postgres, und der auth-Trigger prüft EXECUTE nur beim
-- Anlegen des Triggers, nicht beim Feuern – beide funktionieren ohne Grant.
revoke execute on function public.end_expired_sessions() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Künftige Funktionen (von postgres/Migrationen angelegt) nicht mehr
-- automatisch für PUBLIC/anon ausführbar machen; Grants an authenticated
-- werden ab jetzt pro Funktion bewusst gesetzt.
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon;

-- Bewusst unangetastet: st_estimatedextent (PostGIS-Extension-Funktion);
-- die Extension gehört mittelfristig aus dem public-Schema verschoben
-- (Linter-Regel 0014), ihre ACLs würden bei Extension-Updates ohnehin
-- zurückgesetzt.
