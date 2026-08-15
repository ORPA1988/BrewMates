-- 0023: Hintergrundgeschichten zu Bieren und Brauereien.
--
-- Ein Bier ist selten nur ein Getränk. Hinter den meisten Brauereien im
-- DACH-Raum stehen Jahrhunderte, Klöster, Familienstreits, Kriege und
-- stures Festhalten an einem Rezept. Wer beim Scannen erfährt, dass sein
-- Feierabendbier von einer Brauerei stammt, die seit 1492 braut, trinkt
-- dasselbe Bier anders.
--
-- Zwei bis fünf Sätze, wie ein Mensch sie erzählen würde — kein
-- Werbetext, kein Wikipedia-Auszug. Eigene Formulierungen: Zahlen und
-- Jahreszahlen dürfen aus öffentlichen Quellen stammen, die Sätze müssen
-- unsere sein.
--
-- Bearbeiten darf, wer auch die übrigen Community-Daten pflegen darf
-- (Vertrauensstufe 3+). Dafür ist nichts zu tun: Die bestehenden
-- update-Policies auf beers und breweries gelten für die ganze Zeile und
-- decken die neue Spalte mit ab. Jede Änderung landet wie gehabt im
-- edit_log.
--
-- Die Längengrenze ist kein Formalismus: Sie hält die Geschichten bei
-- „Anekdote" statt „Aufsatz" — und begrenzt, was der Community-Abgleich
-- in die gebündelten JSON-Dateien schiebt.

alter table public.beers
  add column if not exists story text;

alter table public.breweries
  add column if not exists story text;

-- do-Block, weil `add constraint` kein `if not exists` kennt und ein
-- zweiter Lauf sonst mit duplicate_object abbricht.

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'beers_story_length'
  ) then
    alter table public.beers
      add constraint beers_story_length
      check (story is null or char_length(story) <= 1200)
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'breweries_story_length'
  ) then
    alter table public.breweries
      add constraint breweries_story_length
      check (story is null or char_length(story) <= 1200)
      not valid;
  end if;
end $$;
