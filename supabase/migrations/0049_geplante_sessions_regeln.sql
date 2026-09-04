-- 0049: Der Termin in der Zukunft — Teil 2 von 2 (Regeln und Sichtbarkeit).
--
-- Setzt 0048 voraus, das den Enum-Wert `planned` anlegt. Getrennt, weil
-- Postgres einen frisch angelegten Enum-Wert in derselben Transaktion
-- nicht benutzen lässt — Begründung steht dort.
--
-- ============================================================================
-- DIE KARENZ: DREI STUNDEN
--
-- Eine Verabredung, die niemand startet, muss irgendwann verschwinden.
-- Drei Stunden nach dem Termin — dieselbe Spanne, nach der ein laufender
-- Beacon von selbst endet (0001). Kürzer wäre unfreundlich (wer eine
-- halbe Stunde zu spät startet, will die Runde noch haben), länger
-- ließe tote Verabredungen im Weg stehen.
--
-- Die Zahl steht an **zwei** Stellen: in der Sichtbarkeit und im
-- Aufräumen. Das ist Absicht und keine Dublette, die man zusammenlegen
-- sollte: Liefe die Sichtbarkeit länger als das Aufräumen, sähe man
-- Verabredungen, die es nicht mehr gibt; liefe sie kürzer, verschwänden
-- sie vor dem Aufräumen aus der Liste und der Gastgeber könnte sie nicht
-- mehr starten. Sie müssen gleich sein, und deshalb stehen sie
-- nebeneinander in derselben Datei.
--
-- ============================================================================
-- WAS DIE POLICY VORHER TAT — UND WARUM SIE ANGEFASST WERDEN MUSS
--
-- `sessions_select` verlangte für alle außer dem Gastgeber:
--
--     status = 'active' and expires_at > now() and ( … Sichtbarkeit … )
--
-- Eine Verabredung mit `status = 'planned'` wäre damit für **niemanden
-- außer dem Gastgeber** sichtbar gewesen — die Funktion hätte nichts
-- getan, und die Fehlersuche hätte in der App begonnen, während die
-- Ursache hier saß. Live nachgesehen am 2026-09-04, bevor irgendetwas
-- gebaut wurde (docs/features/39, Schritt 1).
--
-- Der Sichtbarkeitsteil bleibt **wortgleich**. Geändert wird nur, welche
-- Zeitbedingung gilt: `expires_at` für laufende, `scheduled_for` für
-- geplante. Wer eine Runde sehen darf, entscheidet weiterhin allein der
-- Kreis bzw. die Crew.
--
-- ============================================================================
-- WAS DIE CHECKS ERZWINGEN
--
-- Eine geplante Session trägt **keinen Standort**. Das ist die
-- Kernentscheidung der Funktion (docs/features/39): Ein Beacon behauptet
-- Anwesenheit, eine Verabredung nur eine Absicht. Als Constraint statt
-- als Client-Regel, weil der Client sie sonst irgendwann umgeht — und
-- weil dieser Constraint der Grund ist, warum ein Fehler in der neuen
-- Policy keinen Aufenthaltsort preisgeben kann.
-- ============================================================================

alter table public.sessions
  drop constraint if exists sessions_planned_needs_date;
alter table public.sessions
  add constraint sessions_planned_needs_date
  check (status <> 'planned' or scheduled_for is not null);

-- `location` ist die PostGIS-Spalte, `latitude`/`longitude` die
-- ausgelagerten Werte für die Karte. Alle drei, sonst wäre die Regel nur
-- halb durchgesetzt.
alter table public.sessions
  drop constraint if exists sessions_planned_has_no_location;
alter table public.sessions
  add constraint sessions_planned_has_no_location
  check (
    status <> 'planned'
    or (location is null and latitude is null and longitude is null)
  );

-- Trägt die Liste „Demnächst" und den Cron-Lauf. Partiell, weil nur ein
-- verschwindender Teil der Zeilen je geplant ist.
create index if not exists sessions_planned_idx
  on public.sessions (scheduled_for)
  where status = 'planned';

-- ============================================================================
-- Sichtbarkeit
-- ============================================================================

drop policy if exists sessions_select on sessions;
create policy sessions_select on sessions for select using (
  host_id = (select auth.uid())
  or (
    (
      (status = 'active' and expires_at > now())
      or (status = 'planned'
          and scheduled_for > now() - interval '3 hours')
    )
    and (
      (visibility = 'friends'
        and public.tier_for(host_id, (select auth.uid())) >= 'freund')
      or (visibility = 'crew'
        and is_crew_member(crew_id, (select auth.uid())))
    )
  )
);

-- ============================================================================
-- Aufräumen
-- ============================================================================

-- Eine Funktion, nicht zwei. Ein zweiter Cron-Eintrag für geplante
-- Sessions wäre ein zweiter Weg, auf dem etwas hängenbleiben kann —
-- und der eine, den niemand mehr anschaut, wenn er einmal läuft.
--
-- Der Zählerschutz ist unangetastet: `count_other_active_sessions`
-- verlangt `latitude is not null`, und das kann eine geplante Session
-- laut Constraint oben nie sein. Sie taucht dort also auch dann nicht
-- auf, wenn sie hier länger stehen bliebe (live geprüft 2026-09-04).
create or replace function end_expired_sessions()
returns void language sql security definer set search_path = public as $$
  update sessions
  set status = 'ended', ended_at = now()
  where (status = 'active' and expires_at <= now())
     or (status = 'planned'
         and scheduled_for <= now() - interval '3 hours');
$$;

comment on function public.end_expired_sessions() is
  'Cron: beendet abgelaufene Beacons und räumt Verabredungen ab, die '
  'drei Stunden nach ihrem Termin nie gestartet wurden.';
