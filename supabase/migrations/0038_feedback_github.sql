-- 0038: Fehler, Wünsche und Roadmap werden in GitHub verwaltet.
--
-- ============================================================================
-- WARUM
--
-- Die Verwaltung (Status setzen, antworten, in die Roadmap übernehmen) soll
-- nicht per SQL laufen, sondern dort, wo sie schon fertig existiert: GitHub
-- Issues mit Labels. Der Tester braucht dafür kein GitHub-Konto — seine
-- Meldung bleibt in `feedback`, die App zeigt ihm weiter Status und Antwort
-- aus Supabase. GitHub ist die Verwaltungsoberfläche, Supabase der Spiegel,
-- den die App liest.
--
-- ============================================================================
-- WIE
--
-- Hin (App → GitHub): AFTER INSERT auf `feedback` ruft per pg_net die Edge
-- Function `feedback-issue`, die ein **anonymes** Issue anlegt (Art,
-- Version, Plattform, Text — kein Name, keine E-Mail) und die Issue-Nummer
-- in `feedback.github_issue` zurückschreibt. AFTER DELETE (Absender zieht
-- zurück) schließt das Issue.
--
-- Zurück (GitHub → App): Ein Actions-Workflow ruft bei jeder Issue-Änderung
-- die Edge Function `github-sync`, die den Stand **aus GitHub liest** und
-- `feedback.status/reply/roadmap_id` sowie `roadmap_items` nachzieht. Sie
-- vertraut dem Aufrufer nichts außer der Issue-Nummer.
--
-- Gemeinsames Geheimnis für den Trigger: dasselbe wie beim Push
-- (`notify_webhook_secret` im Vault, 0033/0034). Fehlt es (CI, frischer
-- Aufbau), geht der Insert trotzdem durch — nur mit Warnung.
--
-- Ein Absender darf `github_issue` nicht selbst setzen (sonst könnte er
-- seine Meldung an ein fremdes Issue hängen): Ein BEFORE-INSERT-Trigger
-- setzt die Spalte auf null; geschrieben wird sie nur von der Edge Function
-- mit der Service-Rolle. Die Policies bleiben unangetastet.
-- ============================================================================

alter table public.feedback add column github_issue integer;
alter table public.roadmap_items add column github_issue integer unique;

comment on column public.feedback.github_issue is
  'Nummer des anonymen GitHub-Issues; setzt nur die Edge Function feedback-issue.';
comment on column public.roadmap_items.github_issue is
  'GitHub-Issue mit Label roadmap, aus dem dieser Punkt gespiegelt wird.';

-- Absender können die Spalte nicht selbst belegen.
create or replace function public.feedback_issue_reset()
returns trigger
language plpgsql as $$
begin
  new.github_issue := null;
  return new;
end $$;

revoke execute on function public.feedback_issue_reset() from public, anon, authenticated;

drop trigger if exists feedback_issue_reset on public.feedback;
create trigger feedback_issue_reset
  before insert on public.feedback
  for each row execute function public.feedback_issue_reset();

-- Hin: Issue anlegen bzw. schließen.
create or replace function public.feedback_issue()
returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_secret text;
  v_body   jsonb;
begin
  select decrypted_secret into v_secret
    from vault.decrypted_secrets
   where name = 'notify_webhook_secret'
   limit 1;

  if v_secret is null then
    raise warning 'notify_webhook_secret fehlt im Vault - kein GitHub-Issue fuer feedback %',
      coalesce(new.id, old.id);
    return coalesce(new, old);
  end if;

  if tg_op = 'DELETE' then
    if old.github_issue is null then
      return old;
    end if;
    v_body := jsonb_build_object('id', old.id, 'deleted', true,
                                 'github_issue', old.github_issue);
  else
    v_body := jsonb_build_object('id', new.id);
  end if;

  perform net.http_post(
    url     := 'https://swlqkwlpnxwthbneblww.supabase.co/functions/v1/feedback-issue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-notify-secret', v_secret
    ),
    body    := v_body,
    timeout_milliseconds := 8000
  );
  return coalesce(new, old);
end $$;

revoke execute on function public.feedback_issue() from public, anon, authenticated;

drop trigger if exists feedback_issue on public.feedback;
create trigger feedback_issue
  after insert or delete on public.feedback
  for each row execute function public.feedback_issue();
