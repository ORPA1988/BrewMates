-- 0035: Sicherheits-Härtung nach dem Check vom 2026-09-02.
--
-- ============================================================================
-- VIER BEFUNDE, VIER MASSNAHMEN
--
-- 1. `anon` hatte INSERT/UPDATE/DELETE auf allen 30 Tabellen (Erbe der
--    Default-Privileges, festgeschrieben in 0025). RLS hat das immer
--    abgefangen — jede Schreib-Policy verlangt `auth.uid()` oder Admin —,
--    aber ein Recht, das nie gebraucht wird, ist eine Tür, die niemand
--    bewacht. Unangemeldete lesen in BrewMates, sie schreiben nie.
--    → DML für `anon` entziehen, auch für künftige Tabellen.
--
-- 2. Der Bucket `beer-photos` hatte weder Größen- noch Typgrenze. Jeder
--    Angemeldete konnte beliebig große Dateien beliebigen Typs hochladen —
--    die App schickt JPEGs um 200 KB, ein Angreifer braucht die App nicht.
--    → 5 MB, nur Bilder. Öffentliches Lesen bleibt: Etikettfotos sollen
--    alle sehen.
--
-- 3. Es gab keine Delete-Policy für Fotos: Wer seinen Check-in löschte,
--    ließ das Bild zurück, für immer und öffentlich.
--    → Eigene Fotos (Ordner = eigene ID) dürfen gelöscht werden.
--
-- 4. `app_config_write` war `for all` und wirkte damit auch als zweite
--    SELECT-Policy (Linter: multiple_permissive_policies).
--    → Auf insert/update/delete beschränkt; Lesen regelt allein
--    `app_config_select`.
--
-- ============================================================================
-- WAS BEWUSST NICHT GEHT
--
-- PostGIS (`spatial_ref_sys` ohne RLS, `st_estimatedextent` als SECURITY
-- DEFINER für anon) gehört `supabase_admin`. Ein REVOKE als `postgres`
-- läuft durch und ändert nichts — live geprüft am 2026-09-02, Rechte
-- unverändert. Beheben ließe sich das nur durch Umzug der Erweiterung ins
-- Schema `extensions` (Drop + Neuanlage bei laufenden Geography-Spalten).
-- Risiko und Nutzen stehen in keinem Verhältnis: `spatial_ref_sys` ist
-- eine öffentliche Referenztabelle (Koordinatensysteme), kein Nutzerdatum.
-- Dasselbe gilt für die anon-Schreibrechte auf `spatial_ref_sys`,
-- `geometry_columns`, `geography_columns` (9 Privilegien, alle
-- supabase_admin): Der REVOKE unten läuft darüber hinweg und ändert dort
-- nichts. Bleibt dokumentierte Baseline.
-- ============================================================================

-- 1. anon schreibt nie.
do $$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname = 'public' loop
    execute format('revoke insert, update, delete on table public.%I from anon', r.tablename);
  end loop;
end $$;
alter default privileges in schema public revoke insert, update, delete on tables from anon;

-- 2. Bucket-Grenzen.
update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'beer-photos';

-- 3. Eigene Fotos löschen dürfen.
drop policy if exists beer_photos_delete on storage.objects;
create policy beer_photos_delete on storage.objects for delete
  using (
    bucket_id = 'beer-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4. Eine Lese-Policy statt zwei.
drop policy if exists app_config_write on app_config;
create policy app_config_insert on app_config for insert
  with check (is_admin(auth.uid()));
create policy app_config_update on app_config for update
  using (is_admin(auth.uid())) with check (is_admin(auth.uid()));
create policy app_config_delete on app_config for delete
  using (is_admin(auth.uid()));
