-- 0054: Vergleich der eigenen Zahlen mit denen der anderen BrewMates
-- (Wunsch #146).
--
-- ============================================================================
-- WAS HIER ENTSCHIEDEN WURDE — UND WAS BEWUSST NICHT GEHT
--
-- Der Wunsch lautete: „Vergleichswerte zu anderen Nutzern bzw. zu
-- Bevölkerungsschichten … Gleichaltrige … Umgebung … Region."
--
-- Davon ist genau ein Teil ohne neue personenbezogene Daten machbar: der
-- Vergleich mit **allen anderen**. Alter kennt die App nicht (kein
-- Geburtsdatum in `profiles`), Wohnort auch nicht — beides zu erheben
-- wäre eine Datenschutz-Entscheidung und gehört dem Menschen, nicht
-- dieser Migration. Region ließe sich aus Check-in-Orten ableiten; das
-- wäre eine Standort-Auswertung über Personen und damit dieselbe Frage.
--
-- ============================================================================
-- WARUM EINE SCHWELLE, UND WARUM 20
--
-- Ein Durchschnitt über wenige Menschen ist kein Aggregat, sondern eine
-- Auskunft über sie. Bei zwei anderen Teilnehmern lässt sich aus „Ø 9"
-- und der eigenen Zahl zurückrechnen, was der andere getrunken hat.
--
-- Deshalb liefert die Funktion Werte erst ab `k_schwelle` beitragenden
-- Personen und sonst nur deren Anzahl. Die App sagt dann ehrlich, dass
-- es noch zu wenige sind. **Diese Zahl zu senken ist eine
-- Datenschutz-Entscheidung** (CLAUDE.md, Regel K) — sie steht hier als
-- Konstante und nicht in `app_config`, damit ihre Änderung durch eine
-- Migration und damit durch eine Prüfung geht.
--
-- Am 2026-09-05 hatten 3 von 6 Konten überhaupt Check-ins. Die Funktion
-- wird also zunächst nichts zeigen. Das ist richtig so: Ein Vergleich
-- mit zwei Personen ist keiner.
--
-- ============================================================================
-- WARUM SECURITY DEFINER
--
-- `checkins` trägt RLS: Der Aufrufer sieht nur eigene, die von Freunden
-- und die seiner Runden. Eine Aggregation als Aufrufer wäre also ein
-- Durchschnitt über den eigenen Freundeskreis — und würde je nach
-- Freundesliste anders ausfallen. Die Funktion sieht deshalb unter RLS
-- hindurch und gibt **ausschließlich Aggregate** heraus, nie eine Zeile
-- und nie eine Identität.
-- ============================================================================

create or replace function public.community_stats(
  p_von timestamptz,
  p_bis timestamptz
)
returns table (
  teilnehmer integer,
  schnitt_checkins numeric,
  schnitt_biere numeric
)
language sql
stable
security definer
set search_path = public
as $$
  -- Als reines SQL mit CTE, nicht als plpgsql mit Temp-Tabelle: Eine
  -- `stable`-Funktion darf nichts anlegen, und die Aggregation braucht
  -- ohnehin nur eine Zwischenstufe.
  with je_person as (
    -- Nur andere: Der eigene Beitrag gehoert auf die andere Seite des
    -- Vergleichs, sonst misst man sich zum Teil an sich selbst.
    select c.profile_id,
           count(*)::numeric as anzahl,
           count(distinct c.beer_id)::numeric as biere
    from checkins c
    where c.created_at >= p_von
      and c.created_at < p_bis
      and c.profile_id is distinct from auth.uid()
    group by c.profile_id
  ),
  n as (select count(*)::integer as k from je_person)
  select n.k,
         -- Die Schwelle steht an beiden Stellen gleich; siehe Kopf.
         case when n.k >= 20 then round(avg(j.anzahl), 1) end,
         case when n.k >= 20 then round(avg(j.biere), 1) end
  from n left join je_person j on true
  group by n.k;
$$;

comment on function public.community_stats(timestamptz, timestamptz) is
  'Anonyme Durchschnitte aller anderen BrewMates in einem Zeitraum. '
  'Liefert Werte erst ab 20 beitragenden Personen, darunter nur deren '
  'Anzahl — ein Durchschnitt ueber wenige ist eine Auskunft ueber sie. '
  'Security definer, weil checkins RLS traegt und die Aggregation sonst '
  'nur den eigenen Freundeskreis erfasste.';

revoke execute on function public.community_stats(timestamptz, timestamptz)
  from public, anon;
grant execute on function public.community_stats(timestamptz, timestamptz)
  to authenticated;
