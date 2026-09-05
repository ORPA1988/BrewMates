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
-- `id = auth.uid()` und deckt jede Spalte ab. Kein neuer Grant, keine
-- neue Policy — nur die Spaltenrechte, die `authenticated` für profiles
-- ohnehin hat, gelten weiter.
-- ============================================================================

alter table public.profiles
  add column if not exists default_visibility public.visibility
  not null default 'friends';

comment on column public.profiles.default_visibility is
  'Sichtbarkeit, mit der neue Check-ins vorbelegt werden. Je Check-in '
  'uebersteuerbar; die Regel selbst steht in checkins_select.';
