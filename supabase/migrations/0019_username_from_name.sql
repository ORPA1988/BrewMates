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

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  base text;
  candidate text;
  hex text := replace(new.id::text, '-', '');
  n int := 0;
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

  if length(base) < 3 then
    candidate := 'mate_' || substr(hex, 1, 10);
  else
    candidate := base;
    while exists (select 1 from public.profiles where username = candidate)
    loop
      n := n + 1;
      if n > 3 then
        candidate := 'mate_' || substr(hex, 1, 10);
        exit;
      end if;
      candidate := base || '_' || substr(hex, 1, 2 * n);
    end loop;
  end if;

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
  return new;
end $$;

-- Konvention seit 0008: Ausführungsrechte explizit halten. Der Trigger
-- läuft als Funktions-Owner; Clients brauchen (und bekommen) kein EXECUTE.
revoke execute on function public.handle_new_user()
  from public, anon, authenticated;
