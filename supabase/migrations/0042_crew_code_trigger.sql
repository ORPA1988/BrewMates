-- 0042: Der Crew-Code entsteht im Trigger, nicht in der Spaltenvorgabe.
--
-- ============================================================================
-- DER FEHLER AUS 0041
--
-- `alter column join_code set default public.neuer_crew_code()` sieht
-- richtig aus und ist es nicht: **Eine Spaltenvorgabe wird mit den
-- Rechten dessen ausgewertet, der einfügt** — nicht mit denen des
-- Tabellenbesitzers. Die Funktion war (bewusst) für `authenticated`
-- gesperrt, also scheiterte jedes Anlegen einer Crew aus der App mit
--
--     permission denied for function neuer_crew_code
--
-- und zwar sofort und für alle. „Crew gründen" war damit kaputt.
--
-- ============================================================================
-- WARUM DAS BEIM PRÜFEN DURCHGERUTSCHT IST
--
-- Der Live-Test nach 0041 hat eine Wegwerf-Crew angelegt und den
-- erzeugten Code kontrolliert — aber **als `postgres`**, und der darf
-- die Funktion aufrufen. Geprüft wurde damit, dass der Code richtig
-- aussieht, nicht dass ihn der richtige Rolleninhaber bekommt.
--
-- Die Lehre steht hier, weil sie sich wiederholen wird: Wer eine Regel
-- prüft, die an Rechten hängt, muss sie in der Rolle prüfen, die sie
-- betrifft. Ein Test als Superuser beantwortet eine andere Frage.
-- Der pgTAP-Test dazu wechselt jetzt ausdrücklich auf `authenticated`.
--
-- ============================================================================
-- DIE LÖSUNG
--
-- Ein `before insert`-Trigger. Er läuft als SECURITY DEFINER, also mit
-- den Rechten seines Eigentümers — die Sperre für `authenticated` bleibt
-- damit bestehen und der Code entsteht trotzdem. Dieselbe Bauart wie bei
-- `friendships_notify` (0031): Die Funktion hängt am Trigger und darf
-- von niemandem direkt gerufen werden.
-- ============================================================================

alter table crews alter column join_code drop default;

create or replace function public.crews_set_join_code()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.join_code is null then
    new.join_code := public.neuer_crew_code();
  end if;
  return new;
end $$;

-- Wie bei jeder Trigger-Funktion in diesem Projekt: Sie gehört dem
-- Trigger, nicht der API.
revoke execute on function public.crews_set_join_code()
  from public, anon, authenticated;

drop trigger if exists crews_set_join_code on crews;
create trigger crews_set_join_code
  before insert on crews
  for each row execute function public.crews_set_join_code();
