-- 0033: Jede neue Benachrichtigung stößt einen Push an.
--
-- ============================================================================
-- WIE
--
-- Ein Trigger auf `notifications` (AFTER INSERT) ruft per `pg_net` die
-- Edge Function `notify` auf — asynchron: Die Anfrage landet in einer
-- Warteschlange, der Insert wartet nicht auf Google. Mitgegeben wird nur
-- die ID; die Function lädt die Zeile selbst nach.
--
-- Das gemeinsame Geheimnis liegt im Supabase-Vault (`notify_webhook_secret`)
-- und wird von beiden Seiten dort gelesen. So steht kein Schlüssel in
-- dieser Datei und keiner im Repo.
--
-- ============================================================================
-- WAS PASSIERT, WENN ETWAS FEHLT
--
-- Fehlt das Geheimnis im Vault (frischer Aufbau, CI), wird **gewarnt und
-- der Insert geht durch**. Eine Freundschaftsanfrage darf nicht daran
-- scheitern, dass Push nicht eingerichtet ist — Push ist ein Zusatz. Die
-- Warnung steht im Postgres-Log; ein pgTAP-Test hält fest, dass der Insert
-- in diesem Fall nicht blockiert.
-- ============================================================================

create extension if not exists pg_net with schema extensions;

create or replace function public.notifications_push()
returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
    from vault.decrypted_secrets
   where name = 'notify_webhook_secret'
   limit 1;

  if v_secret is null then
    raise warning 'notify_webhook_secret fehlt im Vault - kein Push fuer %', new.id;
    return new;
  end if;

  perform net.http_post(
    url     := 'https://swlqkwlpnxwthbneblww.supabase.co/functions/v1/notify',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-notify-secret', v_secret
    ),
    body    := jsonb_build_object('id', new.id),
    timeout_milliseconds := 5000
  );
  return new;
end $$;

revoke execute on function public.notifications_push() from public, anon, authenticated;

drop trigger if exists notifications_push on notifications;
create trigger notifications_push
  after insert on notifications
  for each row execute function public.notifications_push();
