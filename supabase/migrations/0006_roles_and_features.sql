-- Rollen- und Funktionsmodell:
-- * user_roles: Admin-/Moderator-Rollen. Bewusst NICHT als Spalte auf
--   profiles, damit Nutzer sie nicht über ihre eigene Update-Policy
--   setzen können – schreiben dürfen ausschließlich Admins.
-- * user_features: pro Nutzer schaltbare Funktionen (premium, moderation,
--   künftige Features) – vergeben/entzogen von Admins.
-- * Bootstrap: das Konto des Projektinhabers wird bei der Registrierung
--   automatisch Admin (E-Mail-Abgleich im Auth-Trigger).

create table user_roles (
  profile_id uuid primary key references profiles (id) on delete cascade,
  role text not null default 'admin' check (role in ('admin', 'moderator')),
  granted_by uuid references profiles (id) on delete set null,
  granted_at timestamptz not null default now()
);
alter table user_roles enable row level security;

create or replace function is_admin(uid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from user_roles where profile_id = uid and role = 'admin'
  );
$$;
revoke execute on function is_admin(uuid) from anon;

create policy user_roles_select on user_roles for select using (
  profile_id = auth.uid() or is_admin(auth.uid())
);
create policy user_roles_admin_insert on user_roles for insert
  with check (is_admin(auth.uid()));
create policy user_roles_admin_update on user_roles for update
  using (is_admin(auth.uid()));
create policy user_roles_admin_delete on user_roles for delete
  using (is_admin(auth.uid()));

create table user_features (
  profile_id uuid not null references profiles (id) on delete cascade,
  feature text not null check (feature ~ '^[a-z0-9_]{2,40}$'),
  enabled boolean not null default true,
  granted_by uuid references profiles (id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (profile_id, feature)
);
alter table user_features enable row level security;

create policy user_features_select on user_features for select using (
  profile_id = auth.uid() or is_admin(auth.uid())
);
create policy user_features_admin_insert on user_features for insert
  with check (is_admin(auth.uid()));
create policy user_features_admin_update on user_features for update
  using (is_admin(auth.uid()));
create policy user_features_admin_delete on user_features for delete
  using (is_admin(auth.uid()));

-- Bootstrap: Projektinhaber wird bei Registrierung automatisch Admin.
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

  if lower(coalesce(new.email, '')) = 'portbauer23@gmail.com' then
    insert into public.user_roles (profile_id, role)
    values (new.id, 'admin')
    on conflict (profile_id) do nothing;
  end if;

  return new;
end $$;
