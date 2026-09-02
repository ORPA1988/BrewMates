-- GitHub-Spiegel für Feedback und Roadmap (Migration 0038).
-- Ohne Vault-Geheimnis (CI) geht das Melden trotzdem durch; die
-- Issue-Nummer kann ein Absender nicht selbst setzen.
begin;
select plan(6);

create or replace function pg_temp.mkuser(p_id uuid, p_name text)
returns void language plpgsql as $$
begin
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, created_at, updated_at)
  values (p_id, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', p_name || '@test.invalid', '', now(), now());
end $$;
select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'anna');

select has_column('public', 'feedback', 'github_issue',
  'feedback traegt die Issue-Nummer');
select has_column('public', 'roadmap_items', 'github_issue',
  'roadmap_items traegt die Issue-Nummer');
select has_trigger('public', 'feedback', 'feedback_issue',
  'Der GitHub-Trigger haengt an feedback');

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ insert into public.feedback (profile_id, kind, body, app_version, platform, github_issue)
     values ('11111111-1111-1111-1111-111111111111', 'bug',
             'Prost kam nicht an', '0.10.9', 'web', 4711) $$,
  'Ohne Webhook-Geheimnis geht das Melden trotzdem durch (nur Warnung)'
);
select is(
  (select github_issue from public.feedback
    where profile_id = '11111111-1111-1111-1111-111111111111'),
  null,
  'Ein Absender kann github_issue nicht selbst setzen (BEFORE-Trigger nullt)'
);
select lives_ok(
  $$ delete from public.feedback
      where profile_id = '11111111-1111-1111-1111-111111111111' $$,
  'Zurueckziehen ohne Issue-Nummer ruft nichts auf und geht durch'
);

select * from finish();
rollback;
