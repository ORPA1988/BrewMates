-- 0044: Freunde in eine Crew einladen.
--
-- ============================================================================
-- WOZU
--
-- Bisher gab es einen Weg in eine Crew: den Code. Der funktioniert am
-- Tisch — aber nicht für den Stammtisch, der schon existiert und dessen
-- Leute man längst als Freunde hat. Dort will man sagen „komm dazu", und
-- nicht „hier ist ein Code, tipp ihn ein".
--
-- ============================================================================
-- WARUM DIE EINLADUNG ZUGESTIMMT WERDEN MUSS — DER CODE ABER NICHT
--
-- Das sieht wie ein Widerspruch aus und ist der Kern dieser Migration.
--
-- Beim Code entscheidet der **Eingeladene selbst**: Er hält ihn in der
-- Hand und tippt ihn ein. Wer das tut, hat zugestimmt; ein zweiter
-- Bestätigungsschritt wäre eine Rückfrage auf die eigene Handlung.
--
-- Bei einer Einladung entscheidet ein **anderer**. Und in eine Crew
-- gesteckt zu werden ist keine Kleinigkeit: Ein Crew-Beacon zeigt der
-- Crew den **Aufenthaltsort**, und Check-ins während einer Crew-Runde
-- werden für sie sichtbar (`checkins_select`, 0001). Das ist eine
-- Änderung daran, wer was von einem sieht — und darüber entscheidet in
-- dieser App niemand für jemand anderen. Aus demselben Grund braucht eine
-- Freundschaft eine Annahme und entsteht nicht durch einen Scan.
--
-- Deshalb: eine wartende Einladung, die der Eingeladene annimmt oder
-- ablehnt.
--
-- ============================================================================
-- NUR FREUNDE
--
-- Einladen darf man nur, wer schon ein Freund ist. Sonst wäre die
-- Einladung ein Weg, Fremden ungefragt etwas zu schicken — und die
-- Profil-ID eines Fremden bekommt man über den QR-Code leicht genug.
-- Freundschaft gibt es nur beidseitig; damit ist die Einladung an jemanden
-- gerichtet, der den Absender kennt.
-- ============================================================================

create table if not exists crew_invites (
  crew_id uuid not null references crews (id) on delete cascade,
  invitee_id uuid not null references profiles (id) on delete cascade,
  inviter_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (crew_id, invitee_id),
  -- Sich selbst einzuladen ergibt keinen Sinn; wer die Crew anlegt, ist
  -- ohnehin drin.
  check (invitee_id <> inviter_id)
);

-- Jeder Fremdschlüssel braucht einen Index (Regel aus 0036). Der
-- zusammengesetzte Primärschlüssel deckt `crew_id` ab, die beiden
-- anderen nicht.
create index if not exists crew_invites_invitee_idx
  on crew_invites (invitee_id, created_at desc);
create index if not exists crew_invites_inviter_idx
  on crew_invites (inviter_id);

alter table crew_invites enable row level security;

-- Sehen: der Eingeladene (er muss antworten) und die Crew (sie soll
-- wissen, wer noch aussteht). Sonst niemand.
create policy crew_invites_select on crew_invites for select using (
  invitee_id = (select auth.uid())
  or is_crew_member(crew_id, (select auth.uid()))
);

-- Einladen: nur Mitglieder der Crew, nur an Freunde, immer im eigenen
-- Namen. `are_friends` prüft zusätzlich Blockierungen (0009) und
-- beantwortet nur Paare, an denen der Aufrufer beteiligt ist — hier ist
-- er es als Absender.
create policy crew_invites_insert on crew_invites for insert with check (
  inviter_id = (select auth.uid())
  and is_crew_member(crew_id, (select auth.uid()))
  and are_friends(inviter_id, invitee_id)
);

-- Wegnehmen darf beides: der Eingeladene (ablehnen, annehmen) und die
-- Crew (zurückziehen). Ein Annehmen ist ein Insert in `crew_members`
-- plus das Löschen hier — beides darf der Eingeladene ohnehin.
create policy crew_invites_delete on crew_invites for delete using (
  invitee_id = (select auth.uid())
  or is_crew_member(crew_id, (select auth.uid()))
);

-- ============================================================================
-- Die Glocke
--
-- Wie bei den Freundschaftsanfragen (0031): Die Zeile entsteht in der
-- Datenbank, nicht im Client. Ein Client kann vergessen, abstürzen oder
-- alt sein — die Datenbank sieht jede Einladung. Push (0033) und die
-- Nachlese hängen daran ohne weiteres Zutun.
--
-- Verschwindet die Einladung (angenommen, abgelehnt, zurückgezogen),
-- verschwindet die Meldung mit: Eine Glocke, die auf eine Einladung
-- zeigt, die es nicht mehr gibt, führt ins Leere.
-- ============================================================================

create or replace function public.crew_invites_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into notifications
      (recipient_id, type, actor_id, subject_type, subject_id)
    values
      (new.invitee_id, 'crew_invite', new.inviter_id, 'crew', new.crew_id);
    return new;
  end if;

  delete from notifications
   where type = 'crew_invite'
     and recipient_id = old.invitee_id
     and subject_type = 'crew'
     and subject_id = old.crew_id;
  return old;
end $$;

revoke execute on function public.crew_invites_notify()
  from public, anon, authenticated;

drop trigger if exists crew_invites_notify on crew_invites;
create trigger crew_invites_notify
  after insert or delete on crew_invites
  for each row execute function public.crew_invites_notify();
