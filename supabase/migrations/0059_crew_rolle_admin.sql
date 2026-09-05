-- 0059: Die Rolle `admin` für Crews.
--
-- Steht allein, weil Postgres einen frisch angelegten Enum-Wert in
-- derselben Transaktion nicht benutzen lässt — dieselbe Trennung wie
-- 0048/0049 und 0057. Was der Verwalter darf, regelt 0060.
--
-- Entwurf: docs/features/09-crews.md

alter type public.crew_role add value if not exists 'admin';
