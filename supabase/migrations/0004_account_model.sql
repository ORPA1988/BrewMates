-- Identitätsmodell nach Stand der Technik:
-- * auth.users.id (UUID) ist die unveränderliche technische Konto-ID; an ihr
--   hängen die Anmeldeverfahren (E-Mail, Google, später Telefon) als
--   auth.identities – alle änderbar, die ID nie.
-- * Zusätzlich bekommt jedes Profil eine kurze, unveränderliche Kontonummer
--   für Support/Anzeige.
-- * Der Trigger legt bei JEDER Registrierung (auch OAuth/Google) sofort ein
--   Profil mit Platzhalter-Username an; der Nutzer benennt sich danach frei
--   um (Username bleibt global einmalig via unique constraint).

alter table profiles
  add column if not exists account_no bigint generated always as identity;
create unique index if not exists profiles_account_no_idx
  on profiles (account_no);

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, display_name, avatar_emoji)
  values (
    new.id,
    'mate_' || substr(replace(new.id::text, '-', ''), 1, 10),
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      'BrewMate'
    ),
    '🍺'
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
