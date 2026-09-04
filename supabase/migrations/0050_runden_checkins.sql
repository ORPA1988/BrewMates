-- 0050: Wer zusammen trinkt, sieht das auch zusammen.
--
-- ============================================================================
-- WAS FEHLTE
--
-- Ein Check-in landete bisher nur bei den **Freunden** seines Autors. Wer
-- am selben Tisch saß, aber nicht befreundet war, bekam nichts mit —
-- obwohl er danebensaß. Das ist die Lücke zwischen dem, was die App
-- verspricht („kommt vorbei"), und dem, was sie danach zeigt: Eine Runde
-- ist der Moment, in dem sich Leute kennenlernen, und ausgerechnet dort
-- verlangte die App eine Freundschaft, die es noch nicht gibt.
--
-- ============================================================================
-- WIE WEIT DIE SICHTBARKEIT GEHT — UND WIE WEIT NICHT
--
-- Entschieden vom Menschen am 2026-09-04 (Regel K in `CLAUDE.md`):
-- **Die Teilnehmer der Runde, sonst niemand Neues.**
--
-- Ausdrücklich verworfen wurde die weitere Variante, in der alle
-- Mitglieder jeder beteiligten Crew mitlesen. Sie hätte Bier, Bewertung,
-- Notiz und Foto Leuten gezeigt, die nicht dabei waren und die der
-- Einchecker nie ausgewählt hat. Die Crew-Zuordnung bleibt deshalb eine
-- Frage der **Bilanz**, nicht der Sichtbarkeit — und sie braucht hier
-- gar keine Änderung.
--
-- Teilnahme heißt **Zusage** (`kind = 'joined'`, seit 0047): ein Signal,
-- das der Mensch selbst setzt und der Server prüfen kann. Zuprosten oder
-- Absagen zählt nicht — wer „ich schaff's nicht" sagt, war nicht dabei.
--
-- Der **Gastgeber** steht nicht in `session_participants`; er sagt sich
-- nicht selbst zu. Deshalb prüft der Zweig beides, sonst sähe
-- ausgerechnet der Gastgeber die Check-ins seiner eigenen Runde nicht.
--
-- ============================================================================
-- WAS PRIVAT IST, BLEIBT PRIVAT
--
-- `visibility <> 'private'` ist der wichtigste Teil dieser Regel. Wer
-- seinen Check-in ausdrücklich zurückzieht, wird durch eine Runde nicht
-- wieder hervorgeholt. Heute schreibt die App zwar immer 'friends' und
-- der Fall tritt nicht auf — eine Sichtbarkeitsregel baut man trotzdem
-- vollständig, nicht nach dem, was der aktuelle Client zufällig tut.
--
-- ============================================================================
-- WAS DIESE MIGRATION NICHT ANFASST
--
-- Den `crew`-Zweig aus 0001. Er verlangt `visibility = 'crew'` und
-- greift **nie**, weil die App diesen Wert nirgends schreibt (geprüft
-- 2026-09-04). Ihn zu entfernen wäre naheliegend, ist aber eine
-- Entscheidung über die Funktion — entweder bekommt der Mensch die Wahl
-- der Sichtbarkeit, oder der Zweig fällt. Bis dahin bleibt er stehen,
-- wo er ist; er schadet nicht.
--
-- ============================================================================
-- WARUM DAS EINE SECURITY-DEFINER-FUNKTION BRAUCHT
--
-- Der erste Entwurf stellte die Frage direkt in der Policy: ein `exists`
-- über `sessions` und `session_participants`. Die CI hat ihn zerlegt —
-- **sieben Gegenproben grün, ausgerechnet das Öffnen rot.**
--
-- Der Grund: `sessions` trägt selbst RLS. Die Unterabfrage lief als der
-- fragende Mensch, und der sieht die Session eines Nicht-Freundes gar
-- nicht (`sessions_select` verlangt Freundschaft oder Crew). Also fand
-- das `exists` nichts, und die Regel sperrte perfekt, ohne je etwas zu
-- öffnen.
--
-- Deshalb dasselbe Muster wie bei `are_friends`, `is_crew_member` und
-- `tier_for`: eine `security definer`-Funktion, die unter RLS
-- hindurchsieht.
--
-- **Ohne Profil-Parameter, mit Absicht.** `is_my_round(session)` gibt
-- nur über den Aufrufer Auskunft. Ein Parameter `profile` hätte die
-- Funktion zu einem Auskunftsdienst über Dritte gemacht („war X bei
-- Runde S dabei?"), und genau das ist der Maßstab, an dem die Baseline in
-- docs/13 die übrigen Helfer misst: Sie beantworten nur Fragen, an denen
-- der Aufrufer beteiligt ist.
--
-- Entwurf und Begründung: docs/features/40-runden-checkins.md
-- ============================================================================

create or replace function public.is_my_round(p_session uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from sessions s
    where s.id = p_session
      and (
        s.host_id = auth.uid()
        or exists (
          select 1 from session_participants p
          where p.session_id = s.id
            and p.profile_id = auth.uid()
            and p.kind = 'joined'
        )
      )
  );
$$;

comment on function public.is_my_round(uuid) is
  'Gehört diese Runde zu mir — als Gastgeber oder mit Zusage? Security '
  'definer, weil sessions selbst RLS trägt. Nur über den Aufrufer, nie '
  'über Dritte.';

revoke execute on function public.is_my_round(uuid) from public, anon;
grant execute on function public.is_my_round(uuid) to authenticated;

drop policy if exists checkins_select on checkins;
create policy checkins_select on checkins for select using (
  -- Eigene, immer.
  profile_id = (select auth.uid())

  -- Freunde, wie bisher.
  or (visibility = 'friends'
      and are_friends(profile_id, (select auth.uid())))

  -- Crew-Sichtbarkeit aus 0001, unverändert übernommen.
  or (visibility = 'crew'
      and session_id is not null
      and exists (
        select 1 from sessions s
        where s.id = checkins.session_id
          and s.crew_id is not null
          and is_crew_member(s.crew_id, (select auth.uid()))
      ))

  -- NEU: Wer zur selben Runde gehört — als Gastgeber oder mit Zusage.
  or (session_id is not null
      and visibility <> 'private'
      and public.is_my_round(session_id))
);
