-- Meldungen bearbeiten (Migration 0040).
--
-- Zwei Fragen entscheiden hier alles: Wer darf die Liste sehen — und
-- bekommt er dabei mehr zu sehen, als er soll? Der zweite Punkt ist der
-- Grund für die RPC statt eines breiteren Leserechts auf `profiles`.

begin;
select plan(13);

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

select pg_temp.mkuser('11111111-1111-1111-1111-111111111111', 'anna');   -- meldet
select pg_temp.mkuser('22222222-2222-2222-2222-222222222222', 'bert');   -- gemeldet
select pg_temp.mkuser('33333333-3333-3333-3333-333333333333', 'mod');    -- Moderator
select pg_temp.mkuser('44444444-4444-4444-4444-444444444444', 'clara');  -- Unbeteiligte

set local role postgres;

-- Bert stellt sein Profil auf privat: Er ist damit auch für Moderatoren
-- über `profiles` unsichtbar — und muss in der Meldeliste trotzdem einen
-- Namen haben.
update public.profiles set is_private = true
 where id = '22222222-2222-2222-2222-222222222222';

insert into public.user_roles (profile_id, role)
values ('33333333-3333-3333-3333-333333333333', 'moderator');

insert into public.reports (id, reporter_id, reported_id, reason)
values ('a0000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'Beleidigende Nachricht im Kommentar');

-- ============================================================================
-- Die Unbeteiligte sieht nichts.
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

select is(
  (select count(*) from public.reports),
  0::bigint,
  'Wer weder meldet noch moderiert, sieht keine Meldungen'
);

select is(
  (select count(*) from public.moderation_reports('open')),
  0::bigint,
  'Und bekommt auch über die RPC nichts — sie prüft die Rolle selbst'
);

select is(
  public.resolve_report('a0000000-0000-0000-0000-000000000001',
                        'dismissed', 'passt schon'),
  false,
  'Erledigen ohne Rolle tut nichts — und sagt das auch'
);

set local role postgres;
select is(
  (select status from public.reports
    where id = 'a0000000-0000-0000-0000-000000000001'),
  'open',
  'Die Meldung ist unverändert offen'
);

-- ============================================================================
-- Der Meldende sieht seine eigene Meldung — aber nicht die Liste.
-- ============================================================================

set local role authenticated;
set local "request.jwt.claims" =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  (select count(*) from public.reports),
  1::bigint,
  'Der Meldende sieht seine eigene Meldung (Nachvollziehbarkeit)'
);

select is(
  (select count(*) from public.moderation_reports(null)),
  0::bigint,
  'Die Moderationsliste bleibt ihm verschlossen'
);

-- ============================================================================
-- Der Moderator sieht die Liste — samt Namen des privaten Profils.
-- ============================================================================

set local "request.jwt.claims" =
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select is(
  (select count(*) from public.moderation_reports('open')),
  1::bigint,
  'Der Moderator sieht die offene Meldung'
);

select is(
  (select reported_name from public.moderation_reports('open')),
  'bert',
  'Der Name des gemeldeten Profils steht dabei — auch wenn es privat ist'
);

-- Und zwar OHNE dass er das Profil selbst lesen dürfte. Genau dafür gibt
-- es die RPC statt eines breiteren Rechts auf `profiles`.
select is(
  (select count(*) from public.profiles
    where id = '22222222-2222-2222-2222-222222222222'),
  0::bigint,
  'Das private Profil bleibt für ihn im Übrigen unsichtbar'
);

-- ============================================================================
-- Erledigen hinterlässt eine Spur.
-- ============================================================================

select is(
  public.resolve_report('a0000000-0000-0000-0000-000000000001',
                        'resolved', 'Kommentar entfernt, verwarnt'),
  true,
  'Der Moderator kann die Meldung abschließen'
);

select is(
  (select count(*) from public.moderation_reports('open')),
  0::bigint,
  'Danach ist sie aus der Arbeitsliste verschwunden'
);

select is(
  (select handled_by_name from public.moderation_reports('resolved')),
  'mod',
  'Unter „erledigt" steht, wer sie bearbeitet hat'
);

set local role postgres;
select ok(
  (select handled_by = '33333333-3333-3333-3333-333333333333'
       and handled_at is not null
       and note = 'Kommentar entfernt, verwarnt'
       and status = 'resolved'
     from public.reports
    where id = 'a0000000-0000-0000-0000-000000000001'),
  'Wer, wann und mit welchem Befund steht in der Zeile'
);

select * from finish();
rollback;
