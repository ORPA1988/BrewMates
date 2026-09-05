-- 0053: Eine Verabredung, an die niemand erinnert wird, ist eine Notiz.
--
-- ============================================================================
-- ZWEI MELDUNGEN, ZWEI EMPFÄNGERKREISE
--
-- **Beim Anlegen** an alle, die sie sehen dürfen — dieselbe Regel und
-- dieselbe Spam-Bremse wie beim Beacon (0039). Entschieden vom Menschen
-- am 2026-09-05: Variante (a), „wie beim Beacon".
--
-- Zur Wahl standen auch „nur an die Crew" und „gar nicht". Gegen „gar
-- nicht" sprach, dass dann niemand von der Verabredung erfährt, außer er
-- öffnet die App — und ohne Zusagen gäbe es später niemanden zu erinnern.
-- Die Funktion hätte sich selbst ausgehungert.
--
-- **Kurz vorher** nur an die, die zugesagt haben, und an den Gastgeber.
-- Das ist der engere Kreis, und mit Absicht: Wer nicht geantwortet hat,
-- hat damit auch eine Antwort gegeben. Nachhaken gehört Menschen, nicht
-- der App.
--
-- ============================================================================
-- ZWEI STUNDEN VORHER
--
-- Nah genug, dass man noch losfahren kann; weit genug, dass man absagen
-- kann, bevor jemand aufbricht. Der Wert steht als Konstante in der
-- Funktion, nicht im Cron-Ausdruck — wer ihn ändert, ändert ihn an einer
-- Stelle.
--
-- **Genau einmal**, und das braucht ein Gedächtnis: Der Cron läuft alle
-- fünf Minuten, und ohne Merker bekäme jeder Zusagende alle fünf Minuten
-- dieselbe Meldung. Der Merker ist die Meldung selbst — es wird nur
-- eingefügt, wo noch keine steht (`not exists`). Kein zusätzliches Feld,
-- keine zweite Wahrheit.
--
-- ============================================================================
-- WARUM `sessions_notify` ERWEITERT WIRD UND NICHT ERSETZT
--
-- Der Trigger aus 0039 steigt bei allem aus, was nicht `active` ist —
-- eine Verabredung löste deshalb gar nichts aus. Statt eines zweiten
-- Triggers auf derselben Tabelle bekommt er einen zweiten Zweig: Zwei
-- Trigger auf `sessions`, die beide Benachrichtigungen schreiben, wären
-- zwei Orte, an denen dieselbe Spam-Bremse gepflegt werden müsste.
--
-- Beim Start einer Verabredung (`planned` → `active`) greift dann der
-- vorhandene Beacon-Zweig, ohne dass hier etwas Besonderes nötig wäre:
-- Dann ist die Runde wirklich unterwegs, und genau das meldet er.
--
-- Entwurf: docs/features/39-geplante-sessions.md
-- ============================================================================

create or replace function public.sessions_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_typ text;
begin
  if tg_op = 'DELETE' then
    delete from notifications
     where subject_type = 'session' and subject_id = old.id
       and type in ('beacon', 'session_planned', 'session_reminder');
    return old;
  end if;

  -- Welche Art Runde? Alles andere (beendet, abgelaufen) meldet nichts.
  if new.status = 'active' and new.expires_at > now() then
    v_typ := 'beacon';
  elsif new.status = 'planned' and new.scheduled_for > now() then
    v_typ := 'session_planned';
  else
    return new;
  end if;

  -- Nicht zweimal dasselbe: Ein UPDATE an einer Verabredung (Ort, Text)
  -- darf die Meldung nicht wiederholen.
  if exists (
    select 1 from notifications
     where subject_type = 'session' and subject_id = new.id and type = v_typ
  ) then
    return new;
  end if;

  -- Spam-Bremse, wortgleich aus 0039: schon in der letzten Stunde etwas
  -- von diesem Gastgeber?
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
    select k.empfaenger, v_typ, new.host_id, 'session', new.id
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
    select m.profile_id, v_typ, new.host_id, 'session', new.id
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

revoke execute on function public.sessions_notify()
  from public, anon, authenticated;

-- ============================================================================
-- Die Erinnerung kurz vorher
-- ============================================================================

create or replace function public.remind_planned_sessions()
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_vorlauf constant interval := interval '2 hours';
begin
  insert into notifications
    (recipient_id, type, actor_id, subject_type, subject_id)
  select e.empfaenger, 'session_reminder', s.host_id, 'session', s.id
    from sessions s
    cross join lateral (
      -- Der Gastgeber und alle, die zugesagt haben. `union` entdoppelt;
      -- der Gastgeber sagt sich nicht selbst zu, aber ein Blick in die
      -- Zukunft kostet nichts.
      select s.host_id as empfaenger
      union
      select p.profile_id
        from session_participants p
       where p.session_id = s.id and p.kind = 'joined'
    ) e
   where s.status = 'planned'
     and s.scheduled_for > now()
     and s.scheduled_for <= now() + v_vorlauf
     -- Genau einmal je Empfänger. Die vorhandene Meldung IST der Merker:
     -- ein zusätzliches Feld wäre eine zweite Wahrheit, die auseinander
     -- laufen kann.
     and not exists (
       select 1 from notifications n
        where n.subject_type = 'session' and n.subject_id = s.id
          and n.type = 'session_reminder'
          and n.recipient_id = e.empfaenger
     );
end $$;

comment on function public.remind_planned_sessions() is
  'Cron: erinnert zwei Stunden vor dem Termin den Gastgeber und alle, die '
  'zugesagt haben. Genau einmal je Empfänger.';

revoke execute on function public.remind_planned_sessions()
  from public, anon, authenticated;

-- Alle fünf Minuten. Genauer muss es nicht sein: Die Erinnerung kommt
-- „ungefähr zwei Stunden vorher", nicht auf die Sekunde — und ein
-- Minutentakt liefe hundertmal häufiger für dasselbe Ergebnis.
select cron.schedule(
  'remind-planned-sessions',
  '*/5 * * * *',
  $$select public.remind_planned_sessions()$$
);

-- Kein neuer Index: `sessions_planned_idx` aus 0049 ist genau dieser
-- (`(scheduled_for) where status = 'planned'`) und trägt den Cron mit.
-- Ein zweiter mit gleicher Definition kostet Schreiblast für nichts.
