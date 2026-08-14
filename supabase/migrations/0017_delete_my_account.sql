-- 0017: In-App-Kontolöschung (Play-Store-Pflicht für Apps mit
-- Konto-Registrierung).
--
-- Löscht das eigene Profil — die FKs räumen alle Nutzerdaten mit ab
-- (cascade) bzw. anonymisieren Community-Beiträge (set null bei
-- beers/venues/challenges.created_by, edit_log.profile_id) — und
-- anschließend den Auth-Nutzer. Fotos im beer-photos-Bucket bleiben als
-- anonyme Objekte liegen (öffentlicher Bucket, keine Personen-Zuordnung
-- mehr nach der Löschung).
--
-- SECURITY DEFINER (Owner: postgres) darf in auth.users löschen;
-- Grants nach 0008-Konvention: nur authenticated, streng self-scoped
-- über auth.uid().

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Nicht angemeldet.';
  end if;
  delete from public.profiles where id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
