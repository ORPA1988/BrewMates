-- Karten-Zähler: Nicht-Freunde werden auf der Karte NIE verortet, aber im
-- sichtbaren Kartenausschnitt aggregiert gezählt („x weitere BrewMates
-- aktiv"). SECURITY DEFINER, weil die sessions-RLS fremde Sessions
-- (richtigerweise) komplett verbirgt – diese Funktion gibt ausschließlich
-- eine Zahl zurück, nie Positionen oder Identitäten.

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
    and not are_friends(s.host_id, auth.uid());
$$;

revoke execute on function public.count_other_active_sessions(
  double precision, double precision, double precision, double precision
) from anon;
