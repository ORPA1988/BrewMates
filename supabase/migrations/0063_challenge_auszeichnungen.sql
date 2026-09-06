-- Vier Auszeichnungen je Challenge statt einer Trophäe.
--
-- Bis 0.10.27 gab ein abgeschlossener Challenge genau ein Zeichen. Damit
-- lohnt sich Mitmachen nur für den, der ohnehin gewinnt. Jetzt gibt es:
--
--   dabei         Bronze  — jeder, der abschließt
--   beste_crew    Gold    — jedes Mitglied der Crew mit den meisten Abschlüssen
--   schlusslicht  Silber  — der letzte, der FERTIG geworden ist
--   blitzschluck  Platin  — der erste, der fertig war
--
-- Das Metall sagt den Rang, nie das Jahr und nie eine Menge — dieselbe
-- Regel wie bei den Dauerabzeichen (docs/features/11).
--
-- **Vergeben darf nur der Server.** Direkte Inserts sind gesperrt, genau
-- wie bei `challenge_completions` seit 0014: Sonst könnte jeder Client
-- behaupten, Erster gewesen zu sein.

create type challenge_award_kind as enum (
  'dabei', 'beste_crew', 'schlusslicht', 'blitzschluck'
);

create table challenge_awards (
  challenge_id uuid not null references challenges (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  kind challenge_award_kind not null,
  -- Nur bei 'beste_crew' gesetzt: die Crew, für die es vergeben wurde.
  crew_id uuid references crews (id) on delete set null,
  awarded_at timestamptz not null default now(),
  primary key (challenge_id, profile_id, kind)
);
alter table challenge_awards enable row level security;

-- Es gibt je Challenge genau einen Ersten und genau einen Letzten. Der
-- Teilindex erzwingt das in der Datenbank, nicht in der Anwendung: Zwei
-- Abschlüsse in derselben Millisekunde würden sonst zwei Erste erzeugen,
-- und genau das lässt sich in einem Test nur schwer nachstellen.
create unique index challenge_awards_ein_erster
  on challenge_awards (challenge_id) where kind = 'blitzschluck';
create unique index challenge_awards_ein_letzter
  on challenge_awards (challenge_id) where kind = 'schlusslicht';

create index challenge_awards_profile_idx
  on challenge_awards (profile_id, awarded_at desc);

-- Jeder Fremdschlüssel in `public` braucht einen Index (0036). Der
-- Primärschlüssel deckt `challenge_id` ab, der Index darüber
-- `profile_id` — `crew_id` hatte keinen, und der Test hat es gemeldet.
create index challenge_awards_crew_idx
  on challenge_awards (crew_id) where crew_id is not null;

-- Lesen wie bei den Abschlüssen: selbst, Freunde, Admins. Schreiben gar
-- nicht — es gibt bewusst keine insert/update/delete-Policy.
-- `(select auth.uid())` statt `auth.uid()`: Nackt wertet Postgres es für
-- **jede geprüfte Zeile** neu aus, im Subselect einmal als InitPlan
-- (Migration 0036). `performance_0036.test.sql` wacht darüber und hat
-- genau diese Policy im ersten Lauf gefangen.
create policy challenge_awards_select on challenge_awards for select
  using (profile_id = (select auth.uid())
      or are_friends((select auth.uid()), profile_id)
      or is_admin((select auth.uid())));

grant select on challenge_awards to authenticated;

-- ============================================================================
-- Sofort feststehende Auszeichnungen: 'dabei' und 'blitzschluck'
-- ============================================================================
--
-- Beide hängen am Abschluss selbst und brauchen das Ende der Challenge
-- nicht. Ein Trigger auf `challenge_completions` ist hier richtiger als
-- ein Zusatz in `complete_challenge`: Er greift auch dann, wenn ein
-- Abschluss auf einem anderen Weg entsteht (Admin, Nachtrag, künftige
-- RPC), und die Regelprüfung in 0014 bleibt unangetastet.

create or replace function public.vergib_sofortige_auszeichnungen()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into challenge_awards (challenge_id, profile_id, kind)
  values (new.challenge_id, new.profile_id, 'dabei')
  on conflict do nothing;

  -- Ohne Konfliktziel: fängt sowohl den Primärschlüssel (derselbe Mensch
  -- zweimal) als auch den Teilindex (ein zweiter Erster) ab.
  insert into challenge_awards (challenge_id, profile_id, kind)
  values (new.challenge_id, new.profile_id, 'blitzschluck')
  on conflict do nothing;

  return new;
end $$;

create trigger challenge_completions_auszeichnen
  after insert on challenge_completions
  for each row execute function public.vergib_sofortige_auszeichnungen();

-- ============================================================================
-- Nachgereichte Auszeichnungen: 'schlusslicht' und 'beste_crew'
-- ============================================================================

create or replace function public.finalisiere_challenges()
returns integer
language plpgsql security definer set search_path = public as $$
declare
  ch record;
  anzahl integer := 0;
  fertige integer;
begin
  for ch in
    select c.id, c.crew_id
    from challenges c
    where c.ends_at <= now()
      -- Als erledigt gilt, was schon eine nachgereichte Auszeichnung
      -- trägt. Zusätzlich der Zeitstempel: Eine Challenge mit genau einem
      -- Finisher bekommt weder Schlusslicht noch beste Crew und liefe
      -- sonst jede Stunde erneut durch diese Schleife.
      and not exists (
        select 1 from challenge_awards a
        where a.challenge_id = c.id
          and a.kind in ('schlusslicht', 'beste_crew')
      )
      and c.ends_at > now() - interval '90 days'
      and exists (
        select 1 from challenge_completions cc where cc.challenge_id = c.id
      )
  loop
    select count(*) into fertige
    from challenge_completions cc where cc.challenge_id = ch.id;

    -- Schlusslicht erst ab zwei Abschlüssen. Bei genau einem wäre
    -- derselbe Mensch Erster UND Letzter — das liest sich wie Spott und
    -- ist der Grund, warum diese Auszeichnung überhaupt heikel ist.
    if fertige >= 2 then
      insert into challenge_awards (challenge_id, profile_id, kind)
      select cc.challenge_id, cc.profile_id, 'schlusslicht'
      from challenge_completions cc
      where cc.challenge_id = ch.id
      order by cc.completed_at desc, cc.profile_id desc
      limit 1
      on conflict do nothing;
    end if;

    -- Beste Crew: die Crew mit den meisten abschließenden Mitgliedern,
    -- mindestens zwei. Eine Crew aus einer Person wäre keine Crew.
    -- Bei Gleichstand bekommen ALLE gleichauf liegenden Crews die
    -- Auszeichnung — eine willkürliche Entscheidung wäre schlechter als
    -- zwei Sieger.
    --
    -- **Nicht bei Crew-Challenges** (0062): Dort tritt genau eine Crew an,
    -- und „beste Crew" wäre eine Auszeichnung ohne Wettbewerb.
    if ch.crew_id is null then
      insert into challenge_awards (challenge_id, profile_id, kind, crew_id)
      select ch.id, m.profile_id, 'beste_crew', m.crew_id
      from crew_members m
      where m.crew_id in (
        with je_crew as (
          select cm.crew_id, count(distinct cc.profile_id) as fertig
          from challenge_completions cc
          join crew_members cm on cm.profile_id = cc.profile_id
          where cc.challenge_id = ch.id
          group by cm.crew_id
          having count(distinct cc.profile_id) >= 2
        )
        select crew_id from je_crew
        where fertig = (select max(fertig) from je_crew)
      )
      on conflict do nothing;
    end if;

    anzahl := anzahl + 1;
  end loop;

  return anzahl;
end $$;

revoke execute on function public.finalisiere_challenges()
  from public, anon, authenticated;

-- Einmal je Stunde. Genauer muss es nicht sein: Beide Auszeichnungen
-- werden ausdrücklich *nachgereicht*, sobald niemand mehr abschließen
-- kann — auf die Minute genau wäre nur mehr Last für dasselbe Ergebnis.
select cron.schedule(
  'finalize-challenges',
  '7 * * * *',
  $$select public.finalisiere_challenges()$$
);

-- ============================================================================
-- Bestand nachziehen
-- ============================================================================
-- Wer vor dieser Migration abgeschlossen hat, bekommt sein 'dabei'
-- rückwirkend — sonst hätte die Einführung bestehende Abschlüsse
-- entwertet. Ein Erster wird NICHT rückwirkend vergeben: `completed_at`
-- sagt, wer zuerst fertig war, aber die alten Abschlüsse entstanden ohne
-- Wettbewerb, und eine nachträglich erfundene Bestenliste wäre eine
-- Behauptung.
insert into challenge_awards (challenge_id, profile_id, kind)
select cc.challenge_id, cc.profile_id, 'dabei'
from challenge_completions cc
on conflict do nothing;
