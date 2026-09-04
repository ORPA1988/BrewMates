-- Anmeldewege (Migration 0046): die Liste muss ohne Konto lesbar sein.
--
-- Der Punkt ist nicht der Zeileninhalt, sondern wer ihn sieht: Gebraucht
-- wird die Liste von genau dem, der noch kein Konto hat. Wäre sie nur für
-- Angemeldete lesbar, stünde der Anmeldebildschirm ohne Knöpfe da — und
-- niemand käme je in den Zustand, in dem er sie lesen dürfte.
begin;
select plan(4);

select is(
  (select value from public.app_config where key = 'auth_providers'),
  'google',
  'Startwert nennt genau den Anbieter, der wirklich eingerichtet ist'
);

set local role anon;
select is(
  (select count(*) from public.app_config where key = 'auth_providers'),
  1::bigint,
  'Ohne Anmeldung lesbar — sonst gäbe es keinen Anmeldeknopf'
);

-- Wer die Liste setzt, entscheidet, womit sich Menschen anmelden. Das ist
-- keine Community-Aufgabe (dieselbe Haltung wie beim Riegel aus 0029).
select throws_ok(
  $$ update public.app_config set value = 'google,apple'
      where key = 'auth_providers' $$,
  '42501',
  null,
  'anon darf die Liste nicht ändern'
);
reset role;

select is(
  (select value from public.app_config where key = 'auth_providers'),
  'google',
  'und hat sie auch nicht geändert'
);

select * from finish();
rollback;
