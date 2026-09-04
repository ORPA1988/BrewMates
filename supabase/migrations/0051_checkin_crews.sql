-- 0051: Welche Crews bei einer Runde vertreten waren — festgehalten,
-- nicht abgeleitet.
--
-- ============================================================================
-- WARUM GESPEICHERT UND NICHT BERECHNET
--
-- Die Zuordnung wäre ableitbar: Eine Runde gehört zu den Crews ihrer
-- Teilnehmer, und beides steht in der Datenbank. Der erste Entwurf wollte
-- das so machen — mit dem Argument, eine gespeicherte Kopie müsse bei
-- jedem Beitritt und Austritt nachgezogen werden.
--
-- Das Argument stimmt nur, wenn die Kopie die Ableitung nachbilden soll.
-- Sie soll aber etwas anderes: den **damaligen** Stand festhalten. Dann
-- ist keine Pflege nötig, weil sich Vergangenes nicht ändert.
--
-- Den Ausschlag gab dieser Fall: David ist über den Sommer in einer Crew
-- und hat 40 Check-ins in gemeinsamen Runden. Im Oktober tritt er aus.
-- Mit einer Ableitung **fiele die Bilanz der Crew rückwirkend von 60 auf
-- 20** — für Abende, die stattgefunden haben. Eine Bilanz ist ein
-- Rückblick auf Geschehenes; sie darf sich nicht ändern, weil sich heute
-- eine Mitgliederliste ändert.
--
-- ============================================================================
-- WARUM DER SERVER DAS TUN MUSS UND NICHT DER CLIENT
--
-- Keine Geschmacksfrage: `crew_members_select` zeigt eine Mitgliederliste
-- nur den Mitgliedern **dieser** Crew (live geprüft 2026-09-04). Ein
-- Client kann also gar nicht wissen, in welchen Crews die anderen am
-- Tisch sind — und soll es auch nicht wissen. Ein Trigger mit
-- `security definer` sieht, was nötig ist, und gibt nichts davon preis:
-- Er schreibt nur Zeilen, die anschließend derselben Sichtbarkeit
-- unterliegen wie der Check-in selbst.
--
-- ============================================================================
-- ZWEI AUSLÖSER, EINE FUNKTION
--
-- Ein Check-in in einer Runde trägt die Crews aller ein, die zu diesem
-- Zeitpunkt dabei sind. Wer **später** zusagt, bringt seine Crews für die
-- schon vorhandenen Check-ins der Runde nach — sonst hinge die Zuordnung
-- an der Reihenfolge des Abends, und wer als Letzter kommt, zählte für
-- nichts.
--
-- Eine zurückgenommene Zusage räumt **nicht** auf. Der Abend hat
-- stattgefunden; die Zeile beschreibt ihn. Das ist dieselbe Haltung wie
-- oben: Vergangenes ändert sich nicht.
--
-- Entwurf: docs/features/40-runden-checkins.md
-- ============================================================================

create table if not exists public.checkin_crews (
  checkin_id uuid not null references checkins (id) on delete cascade,
  crew_id    uuid not null references crews (id)    on delete cascade,
  created_at timestamptz not null default now(),
  primary key (checkin_id, crew_id)
);

comment on table public.checkin_crews is
  'Welche Crews bei einem Check-in vertreten waren — Momentaufnahme, '
  'nicht abgeleitet. Wird ausschließlich von Triggern gefüllt.';

-- Für die Crew-Bilanz: alle Check-ins einer Crew.
create index if not exists checkin_crews_crew_idx
  on public.checkin_crews (crew_id, created_at desc);

alter table public.checkin_crews enable row level security;

-- Sichtbar genau dann, wenn der Check-in sichtbar ist. Die Unterabfrage
-- läuft als der fragende Mensch, und **hier ist das genau richtig**:
-- `checkins_select` filtert mit, also gibt diese Tabelle nichts preis,
-- was der Check-in nicht ohnehin preisgäbe.
--
-- (Bei 0050 war dieselbe Eigenschaft ein Fehler — dort musste die
-- Unterabfrage unter RLS hindurchsehen. Der Unterschied ist die Frage:
-- „darf ich das sehen?" gehört gefiltert, „gehöre ich dazu?" nicht.)
drop policy if exists checkin_crews_select on public.checkin_crews;
create policy checkin_crews_select on public.checkin_crews for select using (
  exists (select 1 from checkins c where c.id = checkin_crews.checkin_id)
);

-- Kein insert/update/delete für irgendjemanden: Diese Tabelle füllt nur
-- der Trigger. Was niemand schreiben darf, kann auch niemand verfälschen.
grant select on public.checkin_crews to authenticated;

-- ============================================================================
-- Die Zuordnung
-- ============================================================================

create or replace function public.fill_checkin_crews(p_checkin uuid,
                                                     p_session uuid)
returns void
language sql security definer set search_path = public as $$
  insert into checkin_crews (checkin_id, crew_id)
  select distinct cm.crew_id
    from crew_members cm
   where cm.profile_id in (
           select s.host_id from sessions s where s.id = p_session
           union
           select sp.profile_id from session_participants sp
            where sp.session_id = p_session
              and sp.kind = 'joined'
         )
  on conflict do nothing;
$$;

comment on function public.fill_checkin_crews(uuid, uuid) is
  'Trägt die Crews aller Beteiligten einer Runde an einem Check-in ein. '
  'Security definer, weil Crew-Mitgliedschaften Dritter sonst unsichtbar '
  'sind.';

revoke execute on function public.fill_checkin_crews(uuid, uuid)
  from public, anon, authenticated;

-- Auslöser 1: ein neuer Check-in in einer Runde.
create or replace function public.checkins_fill_crews()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.session_id is not null then
    perform public.fill_checkin_crews(new.id, new.session_id);
  end if;
  return new;
end $$;

revoke execute on function public.checkins_fill_crews()
  from public, anon, authenticated;

drop trigger if exists checkins_fill_crews_trg on public.checkins;
create trigger checkins_fill_crews_trg
  after insert on public.checkins
  for each row execute function public.checkins_fill_crews();

-- Auslöser 2: eine Zusage, die später kommt als die ersten Check-ins.
create or replace function public.participants_fill_crews()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.kind = 'joined' then
    perform public.fill_checkin_crews(c.id, new.session_id)
       from checkins c
      where c.session_id = new.session_id;
  end if;
  return new;
end $$;

revoke execute on function public.participants_fill_crews()
  from public, anon, authenticated;

drop trigger if exists participants_fill_crews_trg
  on public.session_participants;
create trigger participants_fill_crews_trg
  after insert on public.session_participants
  for each row execute function public.participants_fill_crews();
