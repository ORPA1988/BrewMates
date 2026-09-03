-- Rechte-Reste (Migration 0045): niemand kommt an RLS vorbei.
--
-- TRUNCATE umgeht RLS. Deshalb ist das hier kein Stil-Test, sondern
-- derselbe Rang wie die Sichtbarkeitstests: Ein einziges Recht dieser Art
-- auf einer einzigen Tabelle macht jede Policy darauf wirkungslos.
--
-- Der Test zählt über den ganzen Katalog statt eine Liste abzuhaken —
-- eine neue Tabelle mit alten Vorgaben soll hier auffallen, nicht beim
-- nächsten Sicherheits-Check.
begin;
select plan(4);

select is(
  (select count(*) from information_schema.table_privileges
    where table_schema = 'public'
      and grantee in ('anon', 'authenticated')
      and privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER')
      and table_name in (
        select c.relname from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind = 'r'
          and pg_get_userbyid(c.relowner) = current_user
      )),
  0::bigint,
  'Keine eigene Tabelle gibt anon oder authenticated TRUNCATE, REFERENCES oder TRIGGER'
);

-- Der Entzug darf nicht ins Leere gelaufen sein: Lesen muss bleiben.
select ok(
  (select count(*) from information_schema.table_privileges
    where table_schema = 'public'
      and grantee = 'authenticated'
      and privilege_type = 'SELECT') > 20,
  'SELECT für authenticated ist unangetastet geblieben'
);

select ok(
  (select count(*) from information_schema.table_privileges
    where table_schema = 'public'
      and grantee = 'anon'
      and privilege_type = 'SELECT') > 20,
  'anon darf weiterhin lesen — begrenzt wird über RLS, nicht über Rechte'
);

-- Die Default-Privileges sind der eigentliche Punkt: Ohne sie käme die
-- nächste Tabelle wieder mit TRUNCATE hoch, so wie crew_invites.
select is(
  (select count(*)
     from pg_default_acl d
     join pg_namespace n on n.oid = d.defaclnamespace
     cross join lateral aclexplode(d.defaclacl) a
     join pg_roles r on r.oid = a.grantee
    where n.nspname = 'public' and d.defaclobjtype = 'r'
      and r.rolname in ('anon', 'authenticated')
      and a.privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER')),
  0::bigint,
  'Künftige Tabellen kommen ohne TRUNCATE, REFERENCES und TRIGGER hoch'
);

select * from finish();
rollback;
