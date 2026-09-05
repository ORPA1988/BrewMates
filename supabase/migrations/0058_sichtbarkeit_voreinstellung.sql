-- 0058: Eine Voreinstellung für die Sichtbarkeit neuer Check-ins.
--
-- Entwurf und Begründung: docs/features/44-sichtbarkeit.md
--
-- ============================================================================
-- WARUM DAS ANS PROFIL GEHÖRT UND NICHT AUFS GERÄT
--
-- Die Voreinstellung ist eine Aussage über einen Menschen („ich möchte
-- grundsätzlich nicht, dass das jemand sieht"), nicht über ein Telefon.
-- Läge sie lokal, gälte sie im Browser nicht — und das zweite Gerät ist
-- in diesem Projekt Anforderung, kein Nice-to-have (Regel J).
--
-- ============================================================================
-- WAS HIER NICHT NÖTIG IST
--
-- Die eigentliche Sichtbarkeit kann die Datenbank längst: `visibility`
-- steht seit 0001 an jedem Check-in, und `checkins_select` wertet alle
-- drei Werte aus — `private` schließt seit 0050 sogar Mitrundige aus.
-- Was fehlte, war ausschließlich die Bedienung in der App. Diese
-- Migration fügt deshalb **eine Spalte** hinzu und rührt keine Regel an.
--
-- Ändern darf sie nur der Besitzer: `profiles_update` (0004) prüft
-- `id = auth.uid()` und deckt jede Spalte ab.
--
-- ============================================================================
-- ABER: RECHTE GELTEN HIER SPALTENWEISE
--
-- Der erste Entwurf endete nach dem `alter table` — „die Policy deckt
-- jede Spalte ab". Die CI hat das in Sekunden widerlegt:
--
--   ERROR: permission denied for table profiles
--
-- Seit 0025/0026 hat `authenticated` auf `profiles` **keine
-- Tabellenrechte, sondern Spaltenrechte** (so wurde `thirsty_until`
-- entzogen, ohne die Tabelle zu sperren). Eine neu angelegte Spalte
-- erbt davon nichts — sie ist für die App unsichtbar und
-- unbeschreibbar, bis sie ausdrücklich freigegeben wird.
--
-- Das ist wörtlich das Muster von 0051/0052: eine Migration, die etwas
-- behauptet, das erst die nächste einlöst. Hier steht beides in einer
-- Datei, und der pgTAP-Test prüft ab jetzt die Rechte mit — nicht nur
-- das Verhalten.
--
-- **Kein INSERT-Recht**: Beim Anlegen eines Profils nennt die App die
-- Spalte nicht, die Vorgabe greift von selbst. Was nicht gebraucht wird,
-- wird nicht gewährt.
-- ============================================================================

alter table public.profiles
  add column if not exists default_visibility public.visibility
  not null default 'friends';

comment on column public.profiles.default_visibility is
  'Sichtbarkeit, mit der neue Check-ins vorbelegt werden. Je Check-in '
  'uebersteuerbar; die Regel selbst steht in checkins_select.';

grant select (default_visibility) on public.profiles to authenticated;
grant update (default_visibility) on public.profiles to authenticated;
