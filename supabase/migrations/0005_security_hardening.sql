-- Härtung nach Supabase-Security-Advisor:
-- interne Funktionen nicht über die REST-RPC-Schnittstelle aufrufbar machen.

-- Nur pg_cron/Trigger sollen diese ausführen – niemals API-Rollen.
revoke execute on function public.end_expired_sessions() from anon, authenticated;
revoke execute on function public.handle_new_user() from anon, authenticated;

-- Policy-Hilfsfunktionen: 'authenticated' braucht EXECUTE (RLS-Policies
-- werten sie im Kontext des Anfragenden aus), 'anon' nie.
revoke execute on function public.are_friends(uuid, uuid) from anon;
revoke execute on function public.is_crew_member(uuid, uuid) from anon;

-- Fester search_path für die Trigger-Funktion.
create or replace function set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;
