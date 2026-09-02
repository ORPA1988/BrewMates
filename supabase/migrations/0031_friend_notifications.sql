-- 0031: Benachrichtigungen für Freundschaftsanfragen — in der Datenbank.
--
-- ============================================================================
-- WOZU
--
-- Bis hierher gab es in BrewMates **keinen** Benachrichtigungsweg. Wer
-- eine Freundschaftsanfrage bekam, erfuhr davon nur, wenn er die App
-- öffnete und der 30-Sekunden-Takt die Liste neu lud. `notifications`
-- existiert seit 0001 als „Quelle der Wahrheit für die In-App-Glocke"
-- (docs/03-architektur.md) — beschrieben hat sie nie jemand.
--
-- Diese Migration füllt sie. Und zwar hier, per Trigger, nicht im
-- Client: Ein Client kann vergessen, abstürzen oder alt sein. Die
-- Datenbank sieht jede Anfrage, egal woher sie kommt.
--
-- Der Push (FCM) hängt später an genau dieser Tabelle — jede neue Zeile
-- ist ein Anlass. Damit ist der Push ein Zusatz und keine zweite Quelle.
--
-- ============================================================================
-- DREI FÄLLE, DREI REAKTIONEN
--
--   Anfrage gestellt   → `friend_request`  an den Empfänger
--   Anfrage angenommen → `friend_accepted` an den, der gefragt hat,
--                        und die offene `friend_request` verschwindet
--   Zeile gelöscht     → alles zu dieser Freundschaft verschwindet
--                        (Ablehnen und Zurücknehmen löschen beide die Zeile)
--
-- Das Verschwinden ist wichtig: Eine Glocke, die eine zurückgenommene
-- Anfrage weiter anzeigt, führt den Menschen zu einer Zeile, die es nicht
-- mehr gibt.
-- ============================================================================

create or replace function public.friendships_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      insert into notifications
        (recipient_id, type, actor_id, subject_type, subject_id)
      values
        (new.addressee_id, 'friend_request', new.requester_id,
         'friendship', new.id);
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.status = 'pending' and new.status = 'accepted' then
      delete from notifications
       where subject_type = 'friendship' and subject_id = new.id
         and type = 'friend_request';
      insert into notifications
        (recipient_id, type, actor_id, subject_type, subject_id)
      values
        (new.requester_id, 'friend_accepted', new.addressee_id,
         'friendship', new.id);
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    delete from notifications
     where subject_type = 'friendship' and subject_id = old.id;
    return old;
  end if;

  return null;
end $$;

-- SECURITY DEFINER, weil `notifications` bewusst keine Insert-Policy hat:
-- Nur der Server schreibt Benachrichtigungen. Die Funktion darf von
-- niemandem direkt aufgerufen werden — sie hängt ausschließlich am Trigger.
revoke execute on function public.friendships_notify() from public, anon, authenticated;

drop trigger if exists friendships_notify on friendships;
create trigger friendships_notify
  after insert or update or delete on friendships
  for each row execute function public.friendships_notify();

-- Löschen dürfen Empfänger ihre eigenen Benachrichtigungen („wegwischen").
-- Lesen und als gelesen markieren konnten sie schon (0001).
drop policy if exists notifications_delete on notifications;
create policy notifications_delete on notifications for delete
  using (recipient_id = auth.uid());

-- Live statt 30-Sekunden-Takt: Realtime liefert neue Zeilen sofort an den
-- angemeldeten Empfänger. RLS gilt auch dort — niemand sieht fremde Zeilen.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table notifications;
  end if;
end $$;
