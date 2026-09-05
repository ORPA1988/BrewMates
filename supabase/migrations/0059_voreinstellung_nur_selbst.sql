-- 0059: Die eigene Sichtbarkeits-Voreinstellung liest nur man selbst.
--
-- ============================================================================
-- DER FEHLER, DEN DAS BEHEBT
--
-- 0058 hat `profiles.default_visibility` angelegt und `select` dafür an
-- `authenticated` gegeben. Spaltenrechte gelten aber **pro Spalte, nicht
-- pro Zeile**: Wer eine fremde Profilzeile sehen darf — jeder Freund,
-- jedes Mitglied derselben Crew —, konnte damit auch lesen, wie privat
-- der andere seine Check-ins hält.
--
-- Aufgefallen ist es beim nächsten Feature, nicht beim Bauen: Dieselbe
-- Spaltenliste speist die Crew-Mitgliederliste. Sichtbar wurde es
-- nirgends, und genau deshalb wäre es niemandem aufgefallen.
--
-- ============================================================================
-- DIE LÖSUNG IST NICHT NEU
--
-- Für `thirsty_until` steht sie seit 0026 da: Spaltenrecht entziehen,
-- und was man über sich selbst wissen darf, kommt über eine Funktion.
-- Eine Zeilenregel (RLS) hilft hier nicht — sie entscheidet über Zeilen,
-- und die fremde Zeile **soll** ja sichtbar sein, nur diese eine Spalte
-- daran nicht.
--
-- `update` bleibt: Wer nichts lesen darf, kann trotzdem schreiben, und
-- die Zeilenregel `profiles_update` lässt ohnehin nur die eigene Zeile zu.
-- ============================================================================

revoke select (default_visibility) on public.profiles from authenticated;

create or replace function public.my_default_visibility()
returns public.visibility
language sql
stable
security definer
set search_path = public
as $$
  select default_visibility from profiles where id = auth.uid();
$$;

comment on function public.my_default_visibility() is
  'Die eigene Voreinstellung fuer die Sichtbarkeit neuer Check-ins. '
  'Ersetzt das Spaltenrecht: Vorbild ist my_thirsty_until() aus 0026 — '
  'Spaltenrechte gelten pro Spalte, nicht pro Zeile.';

revoke execute on function public.my_default_visibility() from public, anon;
grant execute on function public.my_default_visibility() to authenticated;
