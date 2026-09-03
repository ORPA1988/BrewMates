-- 0041: Ein Einladungscode, den man vorlesen kann.
--
-- ============================================================================
-- WOZU
--
-- Der Einladungscode einer Crew ist bisher ihre UUID: 36 Zeichen mit
-- Bindestrichen. Zum Kopieren taugt das, zum QR-Scannen auch — zum
-- SPRECHEN nicht. Und genau das ist der Fall, der übrig bleibt, wenn
-- weder Kamera noch Zwischenablage helfen: am Telefon, über den Tisch
-- gerufen, auf einen Bierdeckel geschrieben.
--
-- Sechs Zeichen aus einem Alphabet ohne Zwillinge: kein 0/O, kein 1/I/L.
-- Wer „B3K-M7Q" hört, tippt „B3KM7Q" und trifft.
--
-- ============================================================================
-- WARUM DER BEITRITT ÜBER EINE FUNKTION LÄUFT
--
-- `crews_select` zeigt nur die eigenen Crews (`is_crew_member`). Das ist
-- richtig so: Wer nicht dabei ist, soll fremde Gruppen nicht durchsuchen
-- können. Damit kann der Client aber auch nicht „welche Crew hat den
-- Code X?" fragen — er sieht die Zeile nicht.
--
-- `join_crew_by_code` beantwortet genau diese eine Frage und nichts
-- sonst: Sie trägt den Aufrufer ein und gibt zurück, welcher Crew er
-- jetzt angehört. Sie verrät **nichts** über Codes, die nicht passen —
-- kein „diese Crew gibt es, du darfst nur nicht", sondern schlicht
-- „unbekannter Code". Sonst wäre sie ein Ratewerkzeug für fremde
-- Gruppennamen.
--
-- ============================================================================
-- ZUR SICHERHEIT DES CODES
--
-- Sechs Zeichen aus 31 sind rund 887 Millionen Möglichkeiten. Das ist
-- kein Geheimnis für die Ewigkeit, aber der Code ist auch keins: Er
-- steht auf dem Tisch, wird vorgelesen und herumgereicht. Wer eine Crew
-- ernsthaft schützen will, tut das nicht mit einem sprechbaren Code —
-- dafür gäbe es Einladungen an bestimmte Personen, und die gibt es
-- bewusst noch nicht.
--
-- Was der Code nicht kann: fremde Daten zeigen. Wer beitritt, sieht die
-- Crew und ihre Runden — mehr nicht, und das ist der Sinn des Beitritts.
-- Rauswerfen kann der Gründer jederzeit (`crew_members_delete` seit
-- 0001).
-- ============================================================================

alter table crews add column if not exists join_code text;

-- Ohne Zwillinge: 0/O und 1/I/L fehlen, damit Vorgelesenes ankommt.
create or replace function public.neuer_crew_code()
returns text
language plpgsql volatile set search_path = public as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
  versuch integer := 0;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from crews where join_code = code);
    versuch := versuch + 1;
    -- Bei 887 Millionen Möglichkeiten heißt der zwanzigste Fehlschlag
    -- nicht „Pech", sondern „hier stimmt etwas nicht".
    if versuch > 20 then
      raise exception 'Kein freier Crew-Code zu finden';
    end if;
  end loop;
  return code;
end $$;
revoke execute on function public.neuer_crew_code() from public, anon, authenticated;

-- Bestandscrews bekommen ihren Code nachträglich.
update crews set join_code = public.neuer_crew_code() where join_code is null;

alter table crews alter column join_code set not null;
alter table crews alter column join_code set default public.neuer_crew_code();

create unique index if not exists crews_join_code_idx on crews (join_code);

comment on column crews.join_code is
  'Sechsstelliger Einladungscode zum Vorlesen. Die UUID bleibt der '
  'technische Schlüssel; dieser hier ist für Menschen.';

-- ------------------------------------------------------------------ Beitritt
--
-- Gibt die Crew-ID zurück, wenn es geklappt hat, sonst null. Ein `null`
-- heißt für den Aufrufer „unbekannter Code" — und zwar auch dann, wenn
-- der Code existiert, aber etwas anderes im Weg war. Alles Feinere wäre
-- eine Auskunft über fremde Gruppen.
create or replace function public.join_crew_by_code(p_code text)
returns uuid
language plpgsql volatile security definer set search_path = public as $$
declare
  v_crew uuid;
  v_me uuid := auth.uid();
begin
  if v_me is null then
    return null;
  end if;

  -- Groß-/Kleinschreibung und Bindestriche verzeihen: Wer „b3k-m7q"
  -- tippt, meint denselben Code.
  select id into v_crew
    from crews
   where join_code = upper(regexp_replace(coalesce(p_code, ''), '[^a-zA-Z0-9]', '', 'g'));

  if v_crew is null then
    return null;
  end if;

  insert into crew_members (crew_id, profile_id)
  values (v_crew, v_me)
  on conflict do nothing;

  return v_crew;
end $$;
revoke execute on function public.join_crew_by_code(text) from public, anon;
grant execute on function public.join_crew_by_code(text) to authenticated;
