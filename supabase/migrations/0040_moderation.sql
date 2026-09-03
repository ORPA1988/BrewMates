-- 0040: Meldungen bekommen einen Bearbeiter.
--
-- ============================================================================
-- WOZU
--
-- Melden funktioniert seit 0009: Die Zeile landet in `reports`, der
-- Meldende sieht sie in seiner eigenen Liste. Danach passiert nichts.
-- Lesen darf sie außer ihm nur ein Admin — und auch der hat keine
-- Oberfläche dafür. Eine Meldung, die niemand ansieht, ist ein
-- Versprechen, das die App nicht hält.
--
-- Drei Lücken, drei Antworten:
--
--   1. MODERATOREN dürfen nicht lesen. Die Rolle existiert seit 0006 und
--      gibt Vertrauensstufe 4 — aber `reports_select` fragt `is_admin`.
--   2. Es gibt kein Feld für „erledigt von wem, wann, mit welchem
--      Befund". `status` allein sagt nicht, ob jemand hingesehen hat.
--   3. Die Liste braucht NAMEN, und die gibt `profiles_select` nicht
--      her: Ein privates Profil ist für Moderatoren genauso unsichtbar
--      wie für alle anderen. Das ist richtig so und bleibt so.
--
-- ============================================================================
-- WARUM EINE RPC UND NICHT EIN BREITERES LESERECHT AUF `profiles`
--
-- Der bequeme Weg wäre, `profiles_select` um „oder is_moderator" zu
-- erweitern. Damit könnte ein Moderator jedes private Profil der App
-- lesen — jederzeit, vollständig, ohne Anlass. Das ist ein Dauerrecht
-- für einen Einzelfall.
--
-- `moderation_reports()` gibt stattdessen genau die Namen heraus, die an
-- einer offenen Meldung hängen, und nur an Moderatoren. Kein Dauerrecht,
-- kein Streifzug durch fremde Profile. Wer mehr können soll, bekommt
-- eine weitere, ebenso enge Funktion.
--
-- ============================================================================
-- WAS DIESE MIGRATION AUSDRÜCKLICH NICHT TUT
--
-- Sie gibt Moderatoren keine Handhabe gegen den Gemeldeten — kein
-- Sperren, kein Löschen, kein Verstecken. Der Grund ist nicht
-- Zurückhaltung, sondern Reihenfolge: Erst muss jemand die Meldungen
-- überhaupt sehen und beantworten können. Was danach an Maßnahmen
-- nötig ist, zeigt sich an echten Fällen — heute gibt es keinen
-- einzigen. Eine Maßnahme auf Vorrat wäre eine Vermutung mit
-- Löschrechten.
-- ============================================================================

-- ---------------------------------------------------------------- Rolle
--
-- Dieselbe Bauart wie `is_admin` (0006): Die Funktion beantwortet nur die
-- Frage nach dem Aufrufer selbst. Ein „ist X Moderator?" über andere wäre
-- eine Auskunft über Fremde und wird hier gar nicht erst möglich.
create or replace function public.is_moderator(uid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select uid = auth.uid()
     and exists (
       select 1 from user_roles
        where profile_id = uid and role in ('admin', 'moderator')
     );
$$;
revoke execute on function public.is_moderator(uuid) from public, anon;
grant execute on function public.is_moderator(uuid) to authenticated;

-- ------------------------------------------------------------- Bearbeitung
alter table reports
  add column if not exists handled_by uuid references profiles (id)
    on delete set null;
alter table reports
  add column if not exists handled_at timestamptz;
alter table reports
  add column if not exists note text
    check (note is null or length(note) between 1 and 2000);

comment on column reports.handled_by is
  'Wer die Meldung bearbeitet hat. Nicht der Vollständigkeit halber: Ohne '
  'diese Spalte sagt `status` nur, dass jemand einen Knopf gedrückt hat.';
comment on column reports.note is
  'Kurzer Befund des Moderators. Sichtbar nur für Moderatoren — nicht für '
  'den Meldenden und nicht für den Gemeldeten.';

-- Jeder Fremdschlüssel in `public` braucht einen Index (Regel aus 0036,
-- durchgesetzt von performance_0036.test.sql).
create index if not exists reports_handled_by_idx on reports (handled_by);

-- ------------------------------------------------------------------ Rechte
--
-- `(select auth.uid())` statt nacktem `auth.uid()`: einmal pro Abfrage
-- statt einmal pro Zeile (0036).
drop policy if exists reports_select on reports;
create policy reports_select on reports for select using (
  reporter_id = (select auth.uid())
  or is_moderator((select auth.uid()))
);

drop policy if exists reports_update on reports;
create policy reports_update on reports for update
  using (is_moderator((select auth.uid())));

-- ------------------------------------------------------------------- Liste
--
-- Gibt die Meldungen samt Namen heraus — das ist der ganze Zweck der
-- Funktion, siehe oben. `p_status = null` heißt „alle", sonst genau
-- dieser Status.
create or replace function public.moderation_reports(p_status text default 'open')
returns table (
  id uuid,
  subject_type text,
  subject_id uuid,
  reason text,
  status text,
  created_at timestamptz,
  note text,
  handled_at timestamptz,
  reporter_id uuid,
  reporter_name text,
  reported_id uuid,
  reported_name text,
  handled_by_name text
)
language sql stable security definer set search_path = public as $$
  select r.id, r.subject_type, r.subject_id, r.reason, r.status,
         r.created_at, r.note, r.handled_at,
         r.reporter_id, pr.display_name,
         r.reported_id, pd.display_name,
         ph.display_name
    from reports r
    join profiles pr on pr.id = r.reporter_id
    join profiles pd on pd.id = r.reported_id
    left join profiles ph on ph.id = r.handled_by
   where public.is_moderator(auth.uid())
     and (p_status is null or r.status = p_status)
   order by r.created_at desc
   limit 200;
$$;
revoke execute on function public.moderation_reports(text) from public, anon;
grant execute on function public.moderation_reports(text) to authenticated;

-- ---------------------------------------------------------------- Erledigen
--
-- Gibt zurück, ob wirklich eine Zeile geändert wurde. Ein `false` ist
-- keine Formalie: Wer glaubt, eine Meldung bearbeitet zu haben, sieht
-- nicht mehr nach (Regel A-8 — keine Erfolgsmeldung ohne Deckung).
create or replace function public.resolve_report(
  p_report uuid,
  p_status text,
  p_note text default null
)
returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare
  v_count integer;
begin
  if not public.is_moderator(auth.uid()) then
    return false;
  end if;
  if p_status not in ('open', 'resolved', 'dismissed') then
    raise exception 'unbekannter Status: %', p_status;
  end if;

  update reports
     set status     = p_status,
         note       = nullif(btrim(coalesce(p_note, '')), ''),
         -- Zurück auf „offen" heißt: noch niemand hat es abgeschlossen.
         -- Den Bearbeiter dann stehen zu lassen, wäre eine falsche Spur.
         handled_by = case when p_status = 'open' then null else auth.uid() end,
         handled_at = case when p_status = 'open' then null else now() end
   where id = p_report;

  get diagnostics v_count = row_count;
  return v_count > 0;
end $$;
revoke execute on function public.resolve_report(uuid, text, text)
  from public, anon;
grant execute on function public.resolve_report(uuid, text, text)
  to authenticated;

-- ============================================================================
-- NACHTRAG: fester search_path für `feedback_issue_reset` (aus 0038)
--
-- Der Linter meldet die Funktion als „search_path mutable". Der Befund ist
-- hier **kosmetisch** und wird trotzdem behoben: Die Funktion ist SECURITY
-- INVOKER, setzt genau ein Feld auf null und fasst keine Tabelle an — mit
-- einem manipulierten `search_path` ließe sich daran nichts drehen.
--
-- Behoben wird er, weil eine Ausnahme in einer Regel, die sonst lückenlos
-- gilt (0005: „Fester search_path für die Trigger-Funktion"), beim nächsten
-- Durchsehen Zeit kostet: Jemand muss erneut prüfen, ob sie harmlos ist.
-- Eine Zeile ist billiger als diese Prüfung.
-- ============================================================================

create or replace function public.feedback_issue_reset()
returns trigger
language plpgsql set search_path = public as $$
begin
  new.github_issue := null;
  return new;
end $$;
