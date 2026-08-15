-- 0028: Mehrere Barcodes je Bier, mit Gebindegröße.
--
-- ============================================================================
-- WARUM
--
-- Eine EAN/GTIN bezeichnet **nicht das Bier, sondern die Handelseinheit**:
-- Produkt plus Verpackung plus Größe. Dieselbe Marke als 0,33-Flasche,
-- 0,5-Dose und Sixpack trägt drei verschiedene Nummern.
--
-- Daraus folgen zwei Dinge, die das bisherige Schema nicht abbildete:
--
-- (1) Ein Bier hat MEHRERE Barcodes. `beers.barcode` (0010) ist eine
--     einzelne Spalte mit UNIQUE — der zweite Code desselben Biers hatte
--     schlicht keinen Platz. Lokal führt die App längst eine Liste; der
--     Server konnte sie nie vollständig aufnehmen.
--
-- (2) Die GRÖSSE gehört an den Code, nicht ans Bier. Sie ist genau das,
--     was zwei EANs desselben Biers unterscheidet. Wer eine 0,33er
--     scannt, soll im Check-in nicht 0,5 vorfinden.
--
-- `beers.barcode` bleibt unangetastet: Ältere Clients lesen und schreiben
-- sie weiter. Diese Tabelle ergänzt, sie ersetzt nicht — ein Entzug wäre
-- ein Bruch für jeden Client vor 0.10.2 (Lehre aus 0024/0026).
-- ============================================================================

create table if not exists beer_barcodes (
  ean text primary key
    check (ean ~ '^[0-9]{8}$' or ean ~ '^[0-9]{13}$'),
  beer_id uuid not null references beers (id) on delete cascade,

  -- Füllmenge in Millilitern. NULL heißt „nicht erfasst" — die App
  -- schätzt dann nach Gebinde und weist das aus. Eine erfundene Zahl
  -- wäre schlimmer als eine fehlende.
  volume_ml integer
    check (volume_ml is null or (volume_ml > 0 and volume_ml <= 20000)),

  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Der Scanner fragt „welches Bier hat diesen Code?" — das ist der
-- Primärschlüssel. Die Gegenrichtung („alle Codes dieses Biers") braucht
-- die Bier-Detailansicht und das Nachtragen.
create index if not exists beer_barcodes_beer_idx on beer_barcodes (beer_id);

alter table beer_barcodes enable row level security;

-- Lesen: wie die Bierdaten selbst. Ein Barcode ist keine persönliche
-- Angabe — er steht auf der Flasche.
drop policy if exists beer_barcodes_select on beer_barcodes;
create policy beer_barcodes_select on beer_barcodes for select
  using (auth.uid() is not null);

-- Anlegen darf jeder Angemeldete: Einen Code nachzutragen ist der
-- häufigste und harmloseste Beitrag überhaupt.
drop policy if exists beer_barcodes_insert on beer_barcodes;
create policy beer_barcodes_insert on beer_barcodes for insert
  with check (auth.uid() is not null and created_by = auth.uid());

-- Ändern und Löschen wie bei Community-Bieren (0013): Ersteller oder ab
-- Stammgast. Eine falsche Zuordnung schickt den Scanner auf das falsche
-- Bier — das soll nicht jeder frisch Registrierte umbiegen können.
drop policy if exists beer_barcodes_update on beer_barcodes;
create policy beer_barcodes_update on beer_barcodes for update
  using (created_by = auth.uid() or account_level(auth.uid()) >= 2);

drop policy if exists beer_barcodes_delete on beer_barcodes;
create policy beer_barcodes_delete on beer_barcodes for delete
  using (created_by = auth.uid() or account_level(auth.uid()) >= 2);

-- Seit 0025 kommen neue Tabellen über die Default-Privileges zu ihren
-- DML-Rechten. Hier trotzdem ausdrücklich: Die Migration soll auch auf
-- einer Datenbank funktionieren, in der jene Voreinstellung fehlt — genau
-- daran scheiterte der Wiederaufbau aus dem Repo schon einmal.
grant select, insert, update, delete on public.beer_barcodes
  to anon, authenticated;

-- Bestehende Einzel-Codes übernehmen, damit der Scanner sofort auch über
-- die neue Tabelle findet, was er vorher fand. Ohne Größe: Die kannte
-- das alte Schema nicht, und sie zu raten wäre falsch.
insert into beer_barcodes (ean, beer_id, created_by)
select b.barcode, b.id, b.created_by
from beers b
where b.barcode is not null
on conflict (ean) do nothing;
