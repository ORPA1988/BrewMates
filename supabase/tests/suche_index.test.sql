-- Prüft, dass die Freundessuche die Trigram-Indizes aus 0027 wirklich
-- benutzt (Backlog B-1).
--
-- Ein Index, den der Planer nicht wählt, ist kein Index — er ist
-- Schreiblast. Deshalb wird hier nicht geprüft, ob er existiert, sondern
-- ob er im Ausführungsplan auftaucht.
--
-- `enable_seqscan = off` ist Absicht: Auf der Testdatenmenge wäre ein
-- Tabellenscan schlicht billiger, und der Planer hätte recht. Die Frage
-- ist nicht, was bei dreihundert Zeilen schneller ist, sondern ob der
-- Index für diese Abfrageform überhaupt in Frage kommt. Genau das
-- beantwortet der erzwungene Plan.

begin;
select plan(4);

-- Genug Zeilen, damit der Plan aussagekräftig ist. Das Profil legt der
-- Trigger handle_new_user selbst an.
insert into auth.users (id, instance_id, aud, role, email,
                        encrypted_password, created_at, updated_at)
select
  ('00000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'testnutzer' || g || '@test.invalid', '', now(), now()
from generate_series(1, 300) g;

analyze public.profiles;

create or replace function pg_temp.plan_nutzt(p_sql text, p_index text)
returns boolean language plpgsql as $$
declare j json;
begin
  execute 'explain (format json) ' || p_sql into j;
  return j::text like '%' || p_index || '%';
end $$;

set local enable_seqscan = off;

select ok(
  pg_temp.plan_nutzt(
    $$select id from public.profiles where display_name ilike '%testnutzer%'$$,
    'profiles_display_name_trgm'),
  'Teilstring-Suche im Anzeigenamen nutzt den Trigram-Index'
);

select ok(
  pg_temp.plan_nutzt(
    $$select id from public.profiles where username ilike 'testnutzer%'$$,
    'profiles_username_trgm'),
  'Präfix-Suche im Nutzernamen nutzt den Trigram-Index'
);

reset enable_seqscan;

-- Und die Suche muss weiterhin das Richtige finden — ein Index, der die
-- Ergebnisse verändert, wäre schlimmer als keiner.
select is(
  (select count(*)::int from public.profiles
    where display_name ilike '%testnutzer1%'),
  (select count(*)::int from public.profiles
    where display_name like '%testnutzer1%'
       or display_name like '%Testnutzer1%'),
  'ilike bleibt unabhängig von Groß-/Kleinschreibung'
);

select is(
  (select count(*)::int from public.profiles
    where username ilike 'gibtesnicht%'),
  0,
  'Kein Treffer bleibt kein Treffer'
);

select * from finish();
rollback;
