-- Eine Challenge, die HEUTE läuft.
--
-- Der Jahresplan aus 0064 beginnt am 19.09. mit der Wiesnzeit. Zwischen
-- dem Einspielen und diesem Datum lägen dreizehn Tage ohne eine einzige
-- laufende Challenge: Die Funktion wäre "scharf geschaltet" und der
-- Bildschirm trotzdem leer.
--
-- Aufgefallen ist das erst beim Gegenlesen am Server — `laeuft_jetzt`
-- stand bei allen zwölf auf false. Ein Plan, der erst in zwei Wochen
-- anfängt, ist kein aktiver Plan.
insert into challenges (id, title, description, emoji, rule,
                        starts_at, ends_at)
values
  ('c0000001-0000-4000-8000-000000000000',
   'Spätsommer',
   'Vier verschiedene Bierstile, bevor die Wiesn losgeht.',
   '🌻',
   '{"type":"distinct_styles","threshold":4}'::jsonb,
   '2026-09-06 00:00 Europe/Vienna'::timestamptz,
   '2026-09-19 00:00 Europe/Vienna'::timestamptz)
on conflict (id) do nothing;
