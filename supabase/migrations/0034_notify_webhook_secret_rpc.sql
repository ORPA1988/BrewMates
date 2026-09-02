-- 0034: Das Webhook-Geheimnis fuer die Edge Function lesbar machen.
--
-- Der Vault ist ueber PostgREST nicht erreichbar — das Schema `vault` ist
-- bewusst nicht freigegeben. Die Function `notify` konnte das Geheimnis
-- deshalb nicht pruefen und antwortete mit 503 (aufgefallen beim ersten
-- Probeaufruf, nicht erst im Betrieb: ein Push-System, das leise nichts
-- tut, war das eine, was nicht passieren durfte).
--
-- Deshalb eine SQL-Funktion in `public`, SECURITY DEFINER, die **nur** die
-- Service-Rolle aufrufen darf. Angemeldete Nutzer und anon bekommen 42501.
create or replace function public.notify_webhook_secret()
returns text
language sql security definer set search_path = public as $$
  select decrypted_secret
    from vault.decrypted_secrets
   where name = 'notify_webhook_secret'
   limit 1;
$$;

revoke execute on function public.notify_webhook_secret() from public, anon, authenticated;
grant execute on function public.notify_webhook_secret() to service_role;
