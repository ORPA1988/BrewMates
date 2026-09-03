-- 0039: Ein neuer Beacon benachrichtigt die, die ihn sehen dürfen.
--
-- ============================================================================
-- WOZU
--
-- Der Beacon ist der virale Kern der App: „Ich bin auf ein Bier unterwegs,
-- alle willkommen." Er erreichte bisher nur, wer die App zufällig offen
-- hatte. Wer sie zu ist, erfährt nichts — und genau der wäre der, den man
-- dazuholen will.
--
-- `notifications` ist seit 0031 der eine Weg dorthin: Jede Zeile weckt
-- über 0033 die Edge Function `notify` und damit das Gerät. Diese
-- Migration schreibt die Zeilen; Glocke, Banner und Push greifen ohne
-- weiteres Zutun. Der Typ heißt `beacon` — die Texte dafür stehen seit
-- dem ersten Tag bereit (`RemoteNotification.text` in der App,
-- `TEXTE.beacon` in der Function) und wurden nie ausgelöst.
--
-- ============================================================================
-- WER ETWAS BEKOMMT — GENAU DIE, DIE DEN BEACON AUCH SEHEN
--
-- Die Empfängerliste ist wortwörtlich die Bedingung aus `sessions_select`
-- (0024), nur andersherum aufgeschrieben:
--
--   visibility = 'friends' → alle Freunde, denen der GASTGEBER mindestens
--                            den Kreis „Freund" zugewiesen hat
--   visibility = 'crew'    → alle Mitglieder dieser Crew
--   visibility = 'private' → niemand
--
-- Das muss zusammenpassen, sonst entsteht der schlimmste aller Fälle: eine
-- Benachrichtigung über etwas, das man beim Hintippen nicht sehen darf.
-- Ein Bekannter, den ich bewusst nicht auf meiner Karte haben will, darf
-- auch kein Telefon klingeln hören.
--
-- Blockierungen schneiden beide Richtungen weg.
--
-- ============================================================================
-- WARUM DIE FUNKTION NICHT `are_friends` BENUTZT
--
-- `are_friends`, `is_blocked` und `is_crew_member` beantworten seit der
-- Härtung in 0009 nur Paare, an denen `auth.uid()` beteiligt ist. Im
-- Trigger IST `auth.uid()` zwar der Gastgeber — aber nur, solange die
-- Zeile aus der App kommt. Ein Insert aus einem Skript, einem Job oder
-- einem künftigen Server-Weg hätte kein `auth.uid()`, und die Funktion
-- lieferte still `false`: keine Benachrichtigung, kein Fehler, keine
-- Spur. Der Trigger fragt die Tabellen deshalb direkt.
--
-- ============================================================================
-- DIE SPAM-BREMSE
--
-- „Höchstens einmal pro Stunde je Person." Gemeint ist die Person, die
-- losgeht: Wer in einer Stunde dreimal startet, weckt seine Freunde
-- einmal.
--
-- Gemessen wird an `sessions`, nicht an `notifications` — obwohl das
-- naheläge. Der Grund steht weiter unten: Endet ein Beacon, verschwinden
-- seine Benachrichtigungen. Läge die Bremse dort, wäre sie mit
-- „starten, beenden, starten" jedes Mal zurückgesetzt. `sessions` bleibt
-- stehen und ist damit das ehrlichere Gedächtnis.
--
-- ============================================================================
-- WAS BEIM BEENDEN PASSIERT
--
-- Die Benachrichtigungen zu dieser Session verschwinden. Dieselbe Regel
-- wie bei der zurückgenommenen Freundschaftsanfrage (0031): Eine Glocke,
-- die auf eine beendete Runde zeigt, führt den Menschen zu etwas, das es
-- nicht mehr gibt — und die RLS zeigt ihm die Session dann auch nicht
-- mehr.
-- ============================================================================

create or replace function public.sessions_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- ------------------------------------------------------------------ Ende
  -- Beendet oder abgelaufen: aufräumen, nicht benachrichtigen.
  if tg_op = 'UPDATE' then
    if new.status = 'ended' and old.status = 'active' then
      delete from notifications
       where type = 'beacon'
         and subject_type = 'session'
         and subject_id = new.id;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    delete from notifications
     where type = 'beacon' and subject_type = 'session' and subject_id = old.id;
    return old;
  end if;

  -- ----------------------------------------------------------------- Start
  if new.status <> 'active' or new.expires_at <= now() then
    return new;
  end if;

  -- Spam-Bremse: schon in der letzten Stunde losgegangen?
  if exists (
    select 1 from sessions s
     where s.host_id = new.host_id
       and s.id <> new.id
       and s.visibility <> 'private'
       and s.started_at > now() - interval '1 hour'
  ) then
    return new;
  end if;

  if new.visibility = 'friends' then
    insert into notifications
      (recipient_id, type, actor_id, subject_type, subject_id)
    select k.empfaenger, 'beacon', new.host_id, 'session', new.id
      from (
        select case when f.requester_id = new.host_id
                    then f.addressee_id else f.requester_id end as empfaenger,
               case when f.requester_id = new.host_id
                    then f.requester_tier else f.addressee_tier end as kreis
          from friendships f
         where f.status = 'accepted'
           and (f.requester_id = new.host_id or f.addressee_id = new.host_id)
      ) k
     where k.kreis >= 'freund'
       and not exists (
         select 1 from blocks b
          where (b.blocker_id = k.empfaenger and b.blocked_id = new.host_id)
             or (b.blocker_id = new.host_id and b.blocked_id = k.empfaenger)
       );

  elsif new.visibility = 'crew' and new.crew_id is not null then
    insert into notifications
      (recipient_id, type, actor_id, subject_type, subject_id)
    select m.profile_id, 'beacon', new.host_id, 'session', new.id
      from crew_members m
     where m.crew_id = new.crew_id
       and m.profile_id <> new.host_id
       and not exists (
         select 1 from blocks b
          where (b.blocker_id = m.profile_id and b.blocked_id = new.host_id)
             or (b.blocker_id = new.host_id and b.blocked_id = m.profile_id)
       );
  end if;

  return new;
end $$;

-- SECURITY DEFINER aus demselben Grund wie bei `friendships_notify`:
-- `notifications` hat bewusst keine Insert-Policy, nur der Server
-- schreibt dort. Direkt aufrufen darf die Funktion niemand.
revoke execute on function public.sessions_notify() from public, anon, authenticated;

drop trigger if exists sessions_notify on sessions;
create trigger sessions_notify
  after insert or update or delete on sessions
  for each row execute function public.sessions_notify();

-- Die Spam-Bremse fragt „hat dieser Gastgeber zuletzt gestartet?". Ohne
-- Index ist das ein Tabellendurchlauf bei jedem neuen Beacon.
create index if not exists sessions_host_started_idx
  on sessions (host_id, started_at desc);
