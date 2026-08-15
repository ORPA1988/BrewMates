-- 0024: Freundeskreise — Bekannte · Freunde · Best Buddys.
--
-- BrewMates zeigt, wo jemand ist und was er trinkt. Das sind Angaben, die
-- man abgestuft teilt: Der Arbeitskollege darf wissen, dass man unterwegs
-- ist — der beste Freund darf wissen, wo. Bisher gab es diese Abstufung
-- nicht, also galt für alle dieselbe Nähe, und das drückt die Zahl der
-- Freundschaften, die man überhaupt eingeht.
--
-- Die Einteilung ist EINSEITIG und PRIVAT: Jeder entscheidet für sich,
-- wen er wie einordnet; der andere erfährt es nicht. Alles andere wäre
-- eine Kränkungsmaschine — niemand soll lesen können, dass er zu den
-- „Bekannten" zählt. Deshalb zwei Spalten je Freundschaftszeile, eine je
-- Richtung.
--
-- Beide Spalten starten auf 'freund'. Damit ändert sich für bestehende
-- Freundschaften am Tag der Migration NICHTS — niemand verliert über
-- Nacht Sichtbarkeit, die er hatte.
--
-- Die Reihenfolge im Aufzählungstyp trägt die Vergleiche: bekannter <
-- freund < buddy. Vergleiche wie `>= 'freund'` funktionieren dadurch
-- ohne Umrechnung.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'friend_tier') then
    create type friend_tier as enum ('bekannter', 'freund', 'buddy');
  end if;
end $$;

alter table public.friendships
  add column if not exists requester_tier friend_tier not null default 'freund';
alter table public.friendships
  add column if not exists addressee_tier friend_tier not null default 'freund';

comment on column public.friendships.requester_tier is
  'Kreis, den der Anfragende dem Adressaten zuweist (privat, einseitig).';
comment on column public.friendships.addressee_tier is
  'Kreis, den der Adressat dem Anfragenden zuweist (privat, einseitig).';

-- ============================================================================
-- tier_for(owner, viewer): Welchen Kreis hat OWNER dem VIEWER zugewiesen?
--
-- Der Besitzer der Information entscheidet, nicht der Betrachter. Diese
-- eine Funktion ist die Grundlage aller Sichtbarkeitsregeln — genau
-- deshalb liegt die Logik hier und nicht verstreut in den Policies: Ein
-- späterer Rückbau ist dann eine Zeile.
--
-- Gibt null zurück, wenn keine (angenommene) Freundschaft besteht oder
-- blockiert wurde; are_friends erledigt beides samt der Härtung, dass nur
-- Paare beantwortet werden, an denen der Anfragende selbst beteiligt ist.
-- ============================================================================

create or replace function public.tier_for(p_owner uuid, p_viewer uuid)
returns friend_tier
language sql stable security definer set search_path = public as $$
  select case
    when not public.are_friends(p_owner, p_viewer) then null
    else (
      select case
               when f.requester_id = p_owner then f.requester_tier
               else f.addressee_tier
             end
      from friendships f
      where f.status = 'accepted'
        and ((f.requester_id = p_owner and f.addressee_id = p_viewer)
          or (f.requester_id = p_viewer and f.addressee_id = p_owner))
      limit 1
    )
  end;
$$;

revoke execute on function public.tier_for(uuid, uuid) from public, anon;
grant execute on function public.tier_for(uuid, uuid) to authenticated;

-- ============================================================================
-- Eigene Einstufung setzen. Nur die eigene Sicht auf den anderen — die
-- Gegenrichtung bleibt unberührt und unsichtbar.
-- ============================================================================

create or replace function public.set_friend_tier(p_other uuid, p_tier friend_tier)
returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  update friendships
     set requester_tier = p_tier
   where status = 'accepted'
     and requester_id = auth.uid()
     and addressee_id = p_other;

  update friendships
     set addressee_tier = p_tier
   where status = 'accepted'
     and addressee_id = auth.uid()
     and requester_id = p_other;
end;
$$;

revoke execute on function public.set_friend_tier(uuid, friend_tier)
  from public, anon;
grant execute on function public.set_friend_tier(uuid, friend_tier)
  to authenticated;

-- ============================================================================
-- Sessions: Der Ort ist die heikelste Angabe der App.
--
-- Ab jetzt sehen nur Freunde und Best Buddys den Beacon. Bekannte sehen
-- ihn nicht mehr als Zeile — sie zählen stattdessen in den aggregierten
-- „weitere BrewMates aktiv"-Zähler, wie Fremde auch.
--
-- Warum nicht „Zeile sichtbar, Position leer"? Weil RLS zeilenweise
-- wirkt: Eine Spalte je Betrachter auszublenden ginge nur über eine
-- eigene Tabelle oder einen Aufruf statt der Tabelle. Die Zeile ganz zu
-- verbergen ist die Regel, die sich hier wirklich durchsetzen lässt — und
-- eine Regel, die nur die App befolgt, ist keine.
-- ============================================================================

drop policy if exists sessions_select on sessions;
create policy sessions_select on sessions for select using (
  host_id = auth.uid()
  or (
    status = 'active' and expires_at > now()
    and (
      (visibility = 'friends'
        and public.tier_for(host_id, auth.uid()) >= 'freund')
      or (visibility = 'crew' and is_crew_member(crew_id, auth.uid()))
    )
  )
);

-- Der Zähler muss mitziehen: Er zählte bisher „keine Freunde". Jetzt zählt
-- er alles, was ich nicht als Beacon sehen darf — sonst verschwänden die
-- Sessions der Bekannten sowohl von der Karte als auch aus der Zahl.
--
-- Der Crew-Ausschluss korrigiert einen Fehler, den schon die bisherige
-- Fassung hatte: Sie zählte „nicht befreundet", die Policy zeigt eine
-- Session aber auch dann, wenn sie auf 'crew' steht und ich Mitglied bin.
-- Ein Crew-Kollege, mit dem ich nicht befreundet bin, erschien deshalb
-- gleichzeitig als Punkt auf der Karte UND in „weitere BrewMates aktiv" —
-- also doppelt. Der Zähler darf nur enthalten, was die Policy verbirgt;
-- die beiden Bedingungen müssen zusammen genau die Sessions abdecken,
-- sonst zählt oder verschweigt die Karte.
create or replace function public.count_other_active_sessions(
  min_lat double precision,
  min_lng double precision,
  max_lat double precision,
  max_lng double precision
)
returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::int
  from sessions s
  where s.status = 'active'
    and s.expires_at > now()
    and s.visibility <> 'private'
    and s.latitude is not null
    and s.longitude is not null
    and s.latitude between min_lat and max_lat
    and s.longitude between min_lng and max_lng
    and s.host_id <> auth.uid()
    and coalesce(public.tier_for(s.host_id, auth.uid()), 'bekannter')
        < 'freund'
    and not (s.visibility = 'crew'
             and public.is_crew_member(s.crew_id, auth.uid()));
$$;

revoke execute on function public.count_other_active_sessions(
  double precision, double precision, double precision, double precision
) from public, anon;
grant execute on function public.count_other_active_sessions(
  double precision, double precision, double precision, double precision
) to authenticated;

-- ============================================================================
-- Bierlaune: dieselbe Abstufung, anderes Mittel.
--
-- thirsty_until ist eine Spalte auf profiles, und ein Profil muss für
-- Freunde sichtbar bleiben — die Zeile zu verbergen scheidet also aus.
-- Deshalb hier der Weg über Spaltenrechte: Die Spalte ist für niemanden
-- mehr direkt lesbar, gelesen wird über zwei Funktionen, die die
-- Abstufung anwenden.
-- ============================================================================

revoke select (thirsty_until) on public.profiles from anon, authenticated;

-- Eigene Bierlaune (das Setzen läuft weiter über die update-Policy).
create or replace function public.my_thirsty_until()
returns timestamptz
language sql stable security definer set search_path = public as $$
  select thirsty_until from profiles where id = auth.uid();
$$;

revoke execute on function public.my_thirsty_until() from public, anon;
grant execute on function public.my_thirsty_until() to authenticated;

-- Freunde mit aktiver Bierlaune — erst ab Kreis „Freund".
create or replace function public.thirsty_friends()
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_emoji text,
  thirsty_until timestamptz
)
language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.display_name, p.avatar_emoji, p.thirsty_until
  from profiles p
  where p.id <> auth.uid()
    and p.thirsty_until is not null
    and p.thirsty_until > now()
    and public.tier_for(p.id, auth.uid()) >= 'freund'
  order by p.display_name;
$$;

revoke execute on function public.thirsty_friends() from public, anon;
grant execute on function public.thirsty_friends() to authenticated;
