-- 0052: Die Tabellenrechte nachziehen, die 0051 nur behauptet hat.
--
-- ============================================================================
-- WAS 0051 FALSCH BESCHRIEB
--
-- Dort steht als Kommentar: „Kein insert/update/delete für irgendjemanden:
-- Diese Tabelle füllt nur der Trigger." Die **Wirkung** stimmt, die
-- **Begründung** nicht — und das ist genau die Sorte Satz, an der dieses
-- Projekt schon einmal teuer gelernt hat (docs/13, Lehre 1).
--
-- Nachgesehen nach dem Einspielen (2026-09-04):
--
--     authenticated : DELETE, INSERT, SELECT, UPDATE
--     anon          : SELECT
--
-- Die Rechte kommen aus den Default-Privileges, nicht aus einem `grant`
-- in 0051. Ein `grant select` fügt hinzu; es entzieht nichts. Dass
-- trotzdem niemand schreiben kann, liegt allein daran, dass RLS an ist
-- und es **keine** insert/update/delete-Policy gibt — der pgTAP-Test
-- belegt das mit einem `throws_ok` auf `42501`.
--
-- Es war also nie ein Loch. Aber eine Sicherung, die anders zustande
-- kommt als der Kommentar sagt, ist eine Sicherung, auf die sich der
-- Nächste falsch verlässt: Wer eine insert-Policy ergänzt, um „nur den
-- Autor" zuzulassen, öffnet damit unabsichtlich das volle DML — weil das
-- Tabellenrecht längst da ist und er glaubt, es sei nicht da.
--
-- Deshalb hier ausdrücklich: erst entziehen, dann geben.
--
-- ============================================================================
-- WARUM AUCH `anon`
--
-- Ein anonymer Zugriff liefert ohnehin nichts: `auth.uid()` ist dann
-- `null`, `checkins_select` gibt keine Zeile her, das `exists` in
-- `checkin_crews_select` bleibt leer. Das SELECT-Recht ist trotzdem
-- überflüssig, und überflüssige Rechte auf einer Tabelle, die
-- Zugehörigkeiten beschreibt, gehören weg.
-- ============================================================================

revoke all on public.checkin_crews from anon;
revoke insert, update, delete, truncate, references
  on public.checkin_crews from authenticated;

grant select on public.checkin_crews to authenticated;
