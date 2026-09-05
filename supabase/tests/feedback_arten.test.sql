-- Lässt sich jede Meldungsart überhaupt speichern?
--
-- Der Anlass steht im Kopf von 0057: Die Art `data` war in App und Edge
-- Function angekommen, im Enum aber nicht — und niemand merkte es, weil
-- die Widget-Tests mit einer Attrappe sprechen und kein pgTAP-Test je
-- eine Meldung **geschrieben** hat.
--
-- Dieser Test schreibt eine je Art. Eine vierte Art geht damit nicht
-- mehr still daneben.
--
-- Ausführen: `supabase test db` (braucht die lokale Instanz).

begin;
select plan(4);

create or replace function pg_temp.mkuser(p_id uuid, p_name text)
returns void language plpgsql as $$
begin
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, created_at, updated_at)
  values (p_id, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', p_name || '@test.invalid', '', now(), now());
  update public.profiles set username = p_name, display_name = p_name
   where id = p_id;
end $$;

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'melder');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok($$
  insert into public.feedback (profile_id, kind, body, app_version, platform)
  values ('11111111-1111-1111-1111-111111111111', 'bug',
          'Etwas ist kaputt.', '0.0.0', 'test')
$$, 'ein Fehler laesst sich melden');

select lives_ok($$
  insert into public.feedback (profile_id, kind, body, app_version, platform)
  values ('11111111-1111-1111-1111-111111111111', 'wish',
          'Etwas waere schoen.', '0.0.0', 'test')
$$, 'ein Wunsch laesst sich melden');

-- Der eigentliche Grund fuer diesen Test.
select lives_ok($$
  insert into public.feedback (profile_id, kind, body, app_version, platform)
  values ('11111111-1111-1111-1111-111111111111', 'data',
          'Gebindegroesse ergaenzt: 0,5 l, EAN 90000019.', '0.0.0', 'test')
$$, 'und eine Datenmeldung auch — der Enum kennt sie seit 0057');

-- Jede Art, die App oder Edge Function kennen, muss hier ankommen.
-- Kaeme eine vierte dazu, faellt sie hier auf.
select is(
  (select count(*)::int from public.feedback
   where profile_id = '11111111-1111-1111-1111-111111111111'),
  3,
  'alle drei Arten stehen in der Tabelle');

select * from finish();
rollback;
