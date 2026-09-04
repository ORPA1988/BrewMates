-- 0047: „Ich komme vorbei" — und „ich schaff's nicht" ist auch eine Antwort.
--
-- ============================================================================
-- WAS FEHLTE
--
-- Ein Beacon sagt „ich bin auf ein Bier unterwegs". Bisher konnte man
-- darauf genau zwei Dinge tun: zuprosten oder zusagen. Wer **nicht** kann,
-- hatte keinen Knopf — und damit fehlte dem Gastgeber die halbe
-- Information. „Drei haben zugesagt" heißt nichts, solange offen ist, ob
-- die anderen fünf noch überlegen oder längst abgesagt haben. Schweigen
-- ist mehrdeutig, und Mehrdeutigkeit ist bei einer Verabredung teuer:
-- Man wartet auf jemanden, der nie kommt.
--
-- Deshalb ein dritter Wert. `participant_kind` heißt jetzt
-- `joined | toast | declined`.
--
-- ============================================================================
-- WARUM „PROST" DANEBEN STEHEN BLEIBT
--
-- Zuprosten und Zu-/Absagen sind zwei verschiedene Fragen: Man kann aus
-- der Ferne zuprosten UND absagen — das ist sogar der häufigste Fall
-- („kann heute nicht, aber trink eins auf mich"). Der Primärschlüssel
-- `(session_id, profile_id, kind)` erlaubt beides nebeneinander, und
-- genau so soll es bleiben.
--
-- Was sich ausschließt, ist Zusage gegen Absage. Das erzwingt **der
-- Client**, indem er die jeweils andere Zeile löscht, bevor er die neue
-- schreibt. Bewusst keine Datenbank-Regel: Ein Ausschluss-Constraint über
-- zwei Zeilen bräuchte einen Trigger, der beim Antworten fremde Zeilen
-- löscht — und ein Trigger, der löscht, was der Aufrufer nicht genannt
-- hat, ist die Art Magie, die man ein Jahr später nicht mehr versteht.
-- Der schlimmste Fall ohne ihn ist eine doppelte Antwort derselben
-- Person, sichtbar und von ihr selbst korrigierbar.
--
-- ============================================================================
-- DIE MELDUNG AN DEN GASTGEBER
--
-- Auch eine Absage weckt ihn. Das ist Absicht: Er hat die Verabredung
-- eröffnet, und „warte nicht auf mich" ist die nützlichste Nachricht des
-- Abends — nützlicher als „jemand hat zugeprostet", das ihn schon heute
-- erreicht. Wird die Absage zurückgenommen, verschwindet die Meldung
-- wieder; das kann der DELETE-Zweig unten schon.
-- ============================================================================

alter type participant_kind add value if not exists 'declined';

-- Eine Stelle für die Zuordnung, nicht zwei. In 0037 stand dasselbe
-- `case` doppelt im Trigger — einmal fürs Anlegen, einmal fürs Aufräumen.
-- Läuft das auseinander, bleibt beim Zurücknehmen eine Meldung stehen,
-- die zu nichts mehr gehört.
--
-- **`k::text` und nicht `k`**: Ein Enum-Literal in einer `language sql`-
-- Funktion wird beim Anlegen aufgelöst. Stünde hier `when 'declined'`,
-- scheiterte die Migration mit „unsafe use of new value of enum type“ —
-- der Wert entsteht drei Zeilen weiter oben, in derselben Transaktion.
-- Über Text verglichen stellt sich die Frage nicht.
create or replace function public.participant_notification_type(k participant_kind)
returns text language sql immutable set search_path = public as $$
  select case k::text
           when 'toast' then 'session_toast'
           when 'declined' then 'session_declined'
           else 'session_joined'
         end
$$;

-- Der Trigger aus 0037 kannte zwei Fälle und behandelte alles, was nicht
-- 'toast' war, als Zusage. Mit dem dritten Wert wäre eine Absage als
-- „ist dabei" gemeldet worden — die glatte Umkehrung.
create or replace function public.session_participants_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_host uuid;
begin
  if tg_op = 'INSERT' then
    select host_id into v_host from sessions where id = new.session_id;
    if v_host is null or v_host = new.profile_id then
      return new;
    end if;
    insert into notifications
      (recipient_id, type, actor_id, subject_type, subject_id)
    values
      (v_host, public.participant_notification_type(new.kind),
       new.profile_id, 'session', new.session_id);
    return new;
  end if;

  if tg_op = 'DELETE' then
    delete from notifications
     where subject_type = 'session' and subject_id = old.session_id
       and actor_id = old.profile_id
       and type = public.participant_notification_type(old.kind);
    return old;
  end if;
  return null;
end $$;

revoke execute on function public.participant_notification_type(participant_kind)
  from public, anon, authenticated;
revoke execute on function public.session_participants_notify()
  from public, anon, authenticated;
