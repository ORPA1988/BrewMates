-- Der Jahresplan (0064): zwölf Challenges, die niemand von Hand nachrechnet.
--
-- Geprüft wird nicht der Inhalt — Titel und Texte darf jeder ändern —,
-- sondern die zwei Zusagen, die dabei still verloren gehen könnten:
-- kein Mengenziel, und keine Challenge, die vor ihrem Start endet.
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

begin;
select plan(5);

select is(
  (select count(*)::int from public.challenges
   where id::text like 'c0000001-0000-4000-8000-%'),
  12, 'Zwölf Challenges aus dem Jahresplan sind angelegt');

-- Der Grundsatz aus docs/01: belohnt werden Vielfalt, Orte und
-- Gemeinsamkeit — nie die Menge. `checkins_count` zählt blanke Check-ins
-- und ist deshalb der eine Regeltyp, den der Jahresplan nicht benutzt.
select is(
  (select count(*)::int from public.challenges
   where id::text like 'c0000001-0000-4000-8000-%'
     and rule ->> 'type' = 'checkins_count'),
  0, 'Keine Challenge des Jahresplans zählt blanke Menge');

select is(
  (select count(*)::int from public.challenges
   where id::text like 'c0000001-0000-4000-8000-%'
     and ends_at <= starts_at),
  0, 'Keine Challenge endet vor ihrem Start');

select is(
  (select count(*)::int from public.challenges
   where id::text like 'c0000001-0000-4000-8000-%'
     and coalesce((rule ->> 'threshold')::int, 0) < 1),
  0, 'Jede Challenge hat ein erreichbares Ziel');

-- `style_specific` ohne `style` gibt in complete_challenge (0014) still
-- `false` zurück — die Challenge wäre unerfüllbar und niemand wüsste warum.
select is(
  (select count(*)::int from public.challenges
   where id::text like 'c0000001-0000-4000-8000-%'
     and rule ->> 'type' = 'style_specific'
     and coalesce(trim(rule ->> 'style'), '') = ''),
  0, 'Jede Stil-Challenge nennt ihren Stil');

select * from finish();
rollback;
