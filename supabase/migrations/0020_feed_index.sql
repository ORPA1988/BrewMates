-- 0020: Index für den Freundes-Feed.
--
-- Der Feed holt die jüngsten Check-ins der Freunde:
--
--   select … from checkins
--   where profile_id <> auth.uid()      -- RLS filtert zusätzlich
--   order by created_at desc
--   limit 30;
--
-- Seit 0001 gibt es checkins_profile_idx (profile_id, created_at desc).
-- Der bedient das eigene Tagebuch optimal (Gleichheit auf der führenden
-- Spalte), dem Feed hilft er jedoch nicht: Dort ist profile_id per <>
-- eingeschränkt, die führende Spalte also nicht auf einen Wert festgelegt.
-- Postgres muss dann alle sichtbaren Zeilen lesen und komplett sortieren.
--
-- Ein eigener Index auf created_at desc macht daraus einen einfachen
-- Rückwärtsdurchlauf, der nach `limit` Zeilen aufhört.
--
-- Bei den heutigen Datenmengen ist das nicht messbar; der Index kostet
-- wenig und verhindert, dass der Feed mit dem Bestand zäh wird.

create index if not exists checkins_created_idx
  on public.checkins (created_at desc);
