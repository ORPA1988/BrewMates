-- 0043: Der Gründer darf seine eigene Crew sehen.
--
-- ============================================================================
-- DER BEFUND
--
-- „Crew gründen" hat **noch nie funktioniert** — nicht seit 0.9.12, als
-- die Funktion eingeführt wurde. In der Datenbank steht bis heute keine
-- einzige Crew, und das ist kein Zufall, sondern die Folge:
--
--   crews_select  →  is_crew_member(id, auth.uid())
--
-- Die App legt die Crew an und liest die neue ID mit `returning` zurück,
-- um danach den Gründer als Mitglied einzutragen. Genau dazwischen
-- klemmt es: **`insert … returning` verlangt zusätzlich die
-- SELECT-Regel**, und die verlangt eine Mitgliedschaft, die es in diesem
-- Augenblick noch nicht geben kann. Postgres meldet das als
--
--   new row violates row-level security policy for table "crews"
--
-- was in die Irre führt — die INSERT-Regel war erfüllt, gescheitert ist
-- das Zurücklesen. Die App zeigte „Crew konnte nicht angelegt werden."
--
-- Henne und Ei: Mitglied wird man erst nach dem Anlegen, sehen darf man
-- erst als Mitglied.
--
-- ============================================================================
-- WARUM DAS SO LANGE UNBEMERKT BLIEB
--
-- Die pgTAP-Tests legten ihre Crews immer als `postgres` an — der
-- umgeht RLS vollständig. Geprüft war damit alles, was NACH dem Anlegen
-- kommt (Beitritt, Sichtbarkeit, Codes), nie das Anlegen selbst. Es ist
-- derselbe blinde Fleck wie in 0042, eine Ebene höher: nicht die falsche
-- Rolle bei einer Funktion, sondern die falsche Rolle bei der ganzen
-- Vorbedingung.
--
-- ============================================================================
-- DIE ÄNDERUNG UND IHRE GRENZE
--
-- `crews_select` erlaubt zusätzlich dem Eigentümer den Blick auf seine
-- eigene Zeile. Das ist keine Ausweitung, die jemandem etwas Neues
-- zeigt: Der Gründer ist per `crews_insert` ohnehin derjenige, der
-- `owner_id = auth.uid()` gesetzt hat, und wird eine Zeile später
-- Mitglied. Fremde Crews bleiben unsichtbar wie bisher — `crew_members`,
-- `sessions` und `checkins` hängen unverändert an `is_crew_member`.
--
-- Nebenbei behebt es einen zweiten, stillen Fall: Schlägt das Eintragen
-- der Mitgliedschaft fehl (Verbindung weg zwischen den beiden
-- Schreibvorgängen), war die Crew bisher für immer unsichtbar — auch für
-- den, der sie angelegt hat. Jetzt sieht er sie und kann sie auflösen.
-- ============================================================================

drop policy if exists crews_select on crews;
create policy crews_select on crews for select using (
  -- `(select auth.uid())` statt nacktem Aufruf: einmal pro Abfrage
  -- statt einmal pro Zeile (Regel aus 0036).
  owner_id = (select auth.uid())
  or is_crew_member(id, (select auth.uid()))
);
