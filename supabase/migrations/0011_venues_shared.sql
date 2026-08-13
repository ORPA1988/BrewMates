-- Gasthäuser als gemeinsame Datenbank (Roadmap Stufe C, Datenpflege):
-- Die seit 0001 existierende, bisher ungenutzte venues-Tabelle wird zur
-- online-first gepflegten Gasthaus-DB mit Preisen und Öffnungszeiten.
-- Die App nutzt einfache lat/lng-Spalten (kein PostGIS im Client);
-- location/osm_id bleiben als Legacy-Spalten unangetastet.

alter table venues add column if not exists latitude double precision
  check (latitude is null or (latitude between -90 and 90));
alter table venues add column if not exists longitude double precision
  check (longitude is null or (longitude between -180 and 180));
alter table venues add column if not exists city text;
alter table venues add column if not exists category text not null default 'gasthaus'
  check (category in
    ('gasthaus','biergarten','bar','brauereigasthof','restaurant','club','sonstiges'));
alter table venues add column if not exists opening_hours text
  check (opening_hours is null or length(opening_hours) <= 500);
alter table venues add column if not exists price_half_l numeric(5,2)
  check (price_half_l is null or price_half_l between 0 and 99);
alter table venues add column if not exists price_third_l numeric(5,2)
  check (price_third_l is null or price_third_l between 0 and 99);
alter table venues add column if not exists created_by uuid
  references profiles (id) on delete set null;
alter table venues add column if not exists updated_at timestamptz not null default now();

create index if not exists venues_latlng_idx on venues (latitude, longitude);
-- Duplikat-Schutz: gleicher Name im gleichen Ort nur einmal (23505 → UI-Hinweis).
create unique index if not exists venues_name_city_key
  on venues (lower(name), lower(coalesce(city, '')));

-- updated_at automatisch pflegen (reine Trigger-Funktion, kein Client-EXECUTE).
create or replace function public.touch_venue()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.touch_venue() from public, anon, authenticated;
create trigger venues_touch before update on venues
  for each row execute function public.touch_venue();

-- Policies: Anlegen an den Ersteller gebunden und immer unverifiziert;
-- Bearbeiten vorerst Ersteller/Admin — Migration 0013 ersetzt das durch das
-- Vertrauensstufen-System. Löschen nur Admin.
drop policy venues_insert on venues;
create policy venues_insert on venues for insert
  with check (created_by = auth.uid() and verified = false);
create policy venues_update on venues for update
  using (created_by = auth.uid() or is_admin(auth.uid()));
create policy venues_delete on venues for delete
  using (is_admin(auth.uid()));
