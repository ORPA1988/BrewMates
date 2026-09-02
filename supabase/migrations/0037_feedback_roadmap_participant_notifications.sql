-- 0037: Prost/„Bin dabei" erreichen den Gastgeber; Feedback und Roadmap.
--
-- ============================================================================
-- TEIL 1 — Prost und „Bin dabei" hatten keine Wirkung
--
-- Beide landeten in `session_participants`. Der Gastgeber erfuhr davon
-- nichts: keine Benachrichtigung, und seine Session-Ansicht zeigte nur
-- lokale Teilnehmer. Der Tester sagte zu Recht „hat keine Funktion".
--
-- Ein Trigger schreibt jetzt eine Benachrichtigung an den Gastgeber
-- (`session_toast` / `session_joined`) — damit greifen Glocke, Banner und
-- Push (0031/0033) ohne weiteres Zutun. Zieht jemand zurück (Zeile weg),
-- verschwindet auch die Benachrichtigung.
--
-- ============================================================================
-- TEIL 2 — Feedback (Fehler, Wünsche) und Roadmap, Testphase
--
-- Tester sollen Fehler und Wünsche mit zwei Tipps loswerden und sehen,
-- was daraus wird. Deshalb zwei Tabellen:
--
--   feedback       — eine Zeile je Meldung, mit Status. Sichtbar für den
--                    Absender (Nachvollziehbarkeit) und für Admins.
--                    Andere Tester sehen fremde Meldungen NICHT.
--   roadmap_items  — für alle lesbar (auch ohne Konto), in Laiensprache,
--                    gepflegt von Admins. Eine Meldung kann auf einen
--                    Roadmap-Punkt zeigen („daraus ist X geworden").
--
-- Ein-/Ausschalten ohne Release über `app_config.feedback_enabled`.
-- ============================================================================

-- ---------------------------------------------------------------- Teil 1
create or replace function public.session_participants_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_host uuid;
begin
  if tg_op = 'INSERT' then
    select host_id into v_host from sessions where id = new.session_id;
    if v_host is null or v_host = new.profile_id then
      return new;
    end if;
    insert into notifications
      (recipient_id, type, actor_id, subject_type, subject_id)
    values
      (v_host,
       case when new.kind = 'toast' then 'session_toast' else 'session_joined' end,
       new.profile_id, 'session', new.session_id);
    return new;
  end if;

  if tg_op = 'DELETE' then
    delete from notifications
     where subject_type = 'session' and subject_id = old.session_id
       and actor_id = old.profile_id
       and type = case when old.kind = 'toast' then 'session_toast' else 'session_joined' end;
    return old;
  end if;
  return null;
end $$;

revoke execute on function public.session_participants_notify() from public, anon, authenticated;

drop trigger if exists session_participants_notify on session_participants;
create trigger session_participants_notify
  after insert or delete on session_participants
  for each row execute function public.session_participants_notify();

-- ---------------------------------------------------------------- Teil 2
create type feedback_kind as enum ('bug', 'wish');
create type feedback_status as enum ('open', 'planned', 'done', 'declined');
create type roadmap_status as enum ('planned', 'in_progress', 'done');

create table roadmap_items (
  id uuid primary key default gen_random_uuid(),
  -- Kurz, in Alltagssprache: „Push, wenn ein Freund losgeht"
  title text not null,
  -- Zwei, drei Sätze: was ändert sich für dich, nicht wie es gebaut ist
  summary text not null,
  status roadmap_status not null default 'planned',
  sort_order int not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger roadmap_items_updated before update on roadmap_items
  for each row execute function set_updated_at();

create table feedback (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  kind feedback_kind not null,
  body text not null check (length(trim(body)) between 3 and 2000),
  app_version text,
  platform text,
  status feedback_status not null default 'open',
  -- Kurze Antwort des Teams, sichtbar für den Absender
  reply text,
  roadmap_id uuid references roadmap_items (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger feedback_updated before update on feedback
  for each row execute function set_updated_at();
create index feedback_profile_idx on feedback (profile_id, created_at desc);
create index feedback_status_idx on feedback (status, created_at desc);
create index feedback_roadmap_idx on feedback (roadmap_id);

alter table roadmap_items enable row level security;
alter table feedback enable row level security;

-- Roadmap: jeder liest, Admins schreiben.
create policy roadmap_select on roadmap_items for select using (true);
create policy roadmap_admin_insert on roadmap_items for insert
  with check (is_admin((select auth.uid())));
create policy roadmap_admin_update on roadmap_items for update
  using (is_admin((select auth.uid())));
create policy roadmap_admin_delete on roadmap_items for delete
  using (is_admin((select auth.uid())));

-- Feedback: eigene Meldungen lesen und anlegen; Admins alles.
create policy feedback_select on feedback for select
  using (profile_id = (select auth.uid()) or is_admin((select auth.uid())));
create policy feedback_insert on feedback for insert
  with check (profile_id = (select auth.uid()) and status = 'open');
create policy feedback_admin_update on feedback for update
  using (is_admin((select auth.uid())));
create policy feedback_own_delete on feedback for delete
  using (profile_id = (select auth.uid()) and status = 'open');

-- Rechte (0025/0035: anon ohne DML, explizit statt geerbt).
grant select on public.roadmap_items to anon, authenticated;
grant insert, update, delete on public.roadmap_items to authenticated;
grant select, insert, update, delete on public.feedback to authenticated;

-- Schalter für die Testphase.
insert into app_config (key, value) values ('feedback_enabled', 'true')
on conflict (key) do nothing;

-- Roadmap-Startbestand, in Laiensprache. Reihenfolge = sort_order.
insert into roadmap_items (title, summary, status, sort_order) values
 ('Beacon auf zwei Geräten',
  'Startest du einen Beacon am Telefon, siehst du ihn auch im Browser – und umgekehrt. Vorher hat das zweite Gerät den Beacon des ersten beendet.',
  'done', 10),
 ('Freundschaftsanfragen sichtbar und annehmbar',
  'Eingehende Anfragen erscheinen auf der Startseite und unter Freunde, mit Annehmen, Ablehnen und Später. Ein Fehler hatte sie zweieinhalb Wochen lang versteckt.',
  'done', 20),
 ('Push-Benachrichtigung bei Anfragen',
  'Dein Telefon meldet sich, wenn jemand dich als Freund hinzufügen will oder deine Anfrage annimmt – auch wenn BrewMates geschlossen ist.',
  'done', 30),
 ('Prost und „Bin dabei" kommen an',
  'Der Gastgeber sieht, wer zugeprostet hat oder dabei ist, und bekommt eine Meldung. Vorher ging beides ins Leere.',
  'in_progress', 40),
 ('Push, wenn ein Freund losgeht',
  '„Anna ist auf ein Bier unterwegs" als Benachrichtigung – höchstens einmal pro Stunde je Person, damit es nicht nervt.',
  'planned', 50),
 ('Gasthäuser nach Preis sortieren',
  'Unter Entdecken die günstigste Halbe in der Nähe finden. Preise tragen alle gemeinsam ein.',
  'done', 60),
 ('Crews per QR-Code',
  'Einer Crew beitreten, indem du einen Code am Tisch scannst – statt eine lange Zeichenfolge zu tippen.',
  'planned', 70),
 ('Web-Version gleichwertig zur App',
  'Wer kein Android hat (z. B. iPhone), nutzt BrewMates im Browser. Alles, was die App kann, soll auch dort gehen – als Nächstes Benachrichtigungen im Browser.',
  'in_progress', 80),
 ('Kamera-Hinweise beim Scannen',
  'Wenn die Kamera nicht erlaubt ist, erklärt die App, was zu tun ist, statt ein schwarzes Bild zu zeigen.',
  'planned', 90),
 ('Rückgängig statt Rückfrage',
  'Beacon beenden, Anfrage ablehnen, Wunschliste leeren – ein Fehltipp lässt sich für ein paar Sekunden zurücknehmen.',
  'planned', 100),
 ('Meldungen bearbeiten (Moderation)',
  'Gemeldete Profile landen bei Moderatoren in einer Liste und werden dort bearbeitet. Heute wird eine Meldung nur gespeichert.',
  'planned', 110),
 ('Veröffentlichung im Play Store',
  'BrewMates offiziell im Store, mit E-Mail-Bestätigung und geprüften Passwörtern. Bis dahin läuft die Testphase über die direkte Installation.',
  'planned', 120);
