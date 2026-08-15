-- 0019: Sprechende Nutzernamen bei der Registrierung.
--
-- Bisher bekam JEDES neue Konto den Nutzernamen mate_<hex> — der echte Name
-- (Google-Name bzw. E-Mail-Präfix) landete nur im display_name. Die
-- Freundessuche matcht aber auf username, weshalb neue Nutzer über ihren
-- Namen praktisch unauffindbar waren. Ab jetzt wird der Nutzername aus
-- full_name/name/E-Mail-Präfix abgeleitet (klein, Umlaute transliteriert,
-- auf [a-z0-9_] reduziert); bei Kollision hängen wir Hex-Zeichen der
-- User-ID an, als letzter Ausweg bleibt das alte mate_<hex>-Schema.
-- Bestehende Profile werden NICHT umbenannt (Nutzername ist öffentlich
-- sichtbar; die Suche findet sie seit dem App-Update über den display_name).
--
-- Diese Fassung ersetzt handle_new_user vollständig und übernimmt darum
-- ausdrücklich den Admin-Bootstrap aus 0006 mit: ohne ihn hätte eine frisch
-- aufgesetzte Datenbank (oder ein neu angelegtes Inhaber-Konto) keinen
-- Administrator, und Moderation, Rollen- und Challenge-Verwaltung ließen
-- sich hinter der RLS nicht mehr in Gang bringen.

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  base text;
  candidate text;
  suffix text;
  hex text := replace(new.id::text, '-', '');
  attempt int := 0;
begin
  base := lower(coalesce(
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(trim(new.raw_user_meta_data->>'name'), ''),
    split_part(coalesce(new.email, ''), '@', 1)
  ));
  base := replace(replace(replace(replace(base,
      'ä', 'ae'), 'ö', 'oe'), 'ü', 'ue'), 'ß', 'ss');
  base := regexp_replace(base, '[^a-z0-9_]+', '_', 'g');
  base := regexp_replace(base, '^_+|_+$', '', 'g');
  base := substr(base, 1, 24);
  -- profiles.username verlangt mindestens 3 Zeichen; sonst gar nicht erst
  -- versuchen, sondern direkt das mate_<hex>-Schema nehmen.
  if length(base) < 3 then
    base := null;
  end if;

  -- Kandidaten der Reihe nach einfügen und die UNIQUE-Verletzung selbst
  -- entscheiden lassen: Ein vorheriges „select … where not exists" wäre
  -- nicht atomar — zwei gleichzeitige Registrierungen mit demselben
  -- abgeleiteten Namen sähen beide „frei" und eine Anmeldung schlüge fehl.
  loop
    attempt := attempt + 1;
    if base is null or attempt > 4 then
      -- Aus der User-ID abgeleitet, damit praktisch kollisionsfrei.
      candidate := 'mate_' || substr(hex, 1, 10);
    elsif attempt = 1 then
      candidate := base;
    else
      suffix := substr(hex, 1, 2 * (attempt - 1));
      -- Höchstens 30 Zeichen (profiles.username-Check): die Basis weicht
      -- dem Suffix, sonst bräche die Registrierung an der Constraint ab.
      candidate := substr(base, 1, 29 - length(suffix)) || '_' || suffix;
    end if;

    begin
      insert into public.profiles (id, username, display_name, avatar_emoji)
      values (
        new.id,
        candidate,
        coalesce(
          nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
          nullif(trim(new.raw_user_meta_data->>'name'), ''),
          'BrewMate'
        ),
        '🍺'
      )
      on conflict (id) do nothing;
      exit;
    exception when unique_violation then
      -- Nutzername schon vergeben → nächster Kandidat. Kollidiert sogar
      -- das mate_<hex>-Schema, liegt ein echter Fehler vor.
      if base is null or attempt > 4 then
        raise;
      end if;
    end;
  end loop;

  -- Bootstrap aus 0006: Projektinhaber wird bei Registrierung automatisch
  -- Admin (sonst gäbe es auf einer frischen Datenbank keinen).
  if lower(coalesce(new.email, '')) = 'portbauer23@gmail.com' then
    insert into public.user_roles (profile_id, role)
    values (new.id, 'admin')
    on conflict (profile_id) do nothing;
  end if;

  return new;
end $$;

-- Konvention seit 0008: Ausführungsrechte explizit halten. Der Trigger
-- läuft als Funktions-Owner; Clients brauchen (und bekommen) kein EXECUTE.
revoke execute on function public.handle_new_user()
  from public, anon, authenticated;
