-- 0056: Fehlende Gebindegrößen melden — Punkte dafür, und Schutz davor.
--
-- Entwurf und Begründung: docs/features/43-fehlende-angaben-melden.md
--
-- ============================================================================
-- WARUM DER LOG-EINTRAG AUF DAS BIER GEHT UND NICHT AUF DEN BARCODE
--
-- Punkte entstehen in diesem Projekt nicht aus einer eigenen Tabelle,
-- sondern aus dem, was jemand getan hat: `account_level` zählt
-- `edit_log`-Einträge mit `action = 'update'` doppelt (0013). Wer eine
-- fehlende Größe nachträgt, soll dieselben zwei Punkte bekommen wie für
-- jede andere Datenpflege — ohne ein zweites Punktesystem daneben.
--
-- `edit_log.entity_id` ist aber **uuid**, und ein Barcode hat keine: Sein
-- Schlüssel ist die EAN, ein Text. Deshalb wird das **Bier** protokolliert
-- (`entity = 'beer'`, `entity_id = beer_id`), und die EAN steht in
-- `changes`. Das ist auch inhaltlich richtig: Ergänzt wurde etwas über
-- dieses Bier.
--
-- ============================================================================
-- WARUM ÜBERSCHREIBEN ETWAS ANDERES IST ALS FÜLLEN
--
-- Eine **leere** Angabe zu füllen kostet nichts: Vorher wusste niemand
-- etwas, nachher steht eine Vermutung da, die eine Prüfung durchläuft.
-- Eine **vorhandene** Angabe zu ändern kann dagegen eine geprüfte durch
-- einen Fehltipp ersetzen.
--
-- Deshalb dieselbe Grenze wie bei der übrigen Community-Bearbeitung
-- (0013): füllen darf jeder Angemeldete, überschreiben erst ab
-- Vertrauensstufe 2. Die Regel steht im Trigger und nicht in der App —
-- eine Grenze, die nur der Client kennt, umgeht der nächste Client.
--
-- Die Prüfung läuft über `account_level(auth.uid())`. Die Funktion gibt
-- für fremde Konten 0 zurück, hier fragt aber jeder nach sich selbst.
-- ============================================================================

create or replace function public.beer_barcode_edit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alt integer := case when tg_op = 'UPDATE' then old.volume_ml end;
begin
  -- Nichts Inhaltliches geändert → kein Log-Rauschen, keine Punkte.
  if tg_op = 'UPDATE' and new.volume_ml is not distinct from v_alt then
    return new;
  end if;
  if new.volume_ml is null then
    return new;
  end if;

  insert into edit_log (entity, entity_id, profile_id, action, changes)
  values (
    'beer', new.beer_id, auth.uid(), 'update',
    jsonb_build_object(
      'volume_ml', jsonb_build_object('alt', v_alt, 'neu', new.volume_ml),
      'ean', new.ean));
  return new;
end $$;

comment on function public.beer_barcode_edit_log() is
  'Protokolliert eine ergaenzte Gebindegroesse als Bearbeitung des Biers '
  '— dadurch zaehlt sie in account_level wie jede andere Datenpflege.';

revoke execute on function public.beer_barcode_edit_log()
  from public, anon, authenticated;

drop trigger if exists beer_barcodes_edit_log on public.beer_barcodes;
create trigger beer_barcodes_edit_log
  after insert or update on public.beer_barcodes
  for each row execute function public.beer_barcode_edit_log();

-- ----------------------------------------------------------------------------
-- Ueberschreiben nur ab Vertrauensstufe 2
-- ----------------------------------------------------------------------------

create or replace function public.beer_barcode_volume_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Moderatoren und Admins (Stufe 4/5) kommen ueber dieselbe Abfrage
  -- durch; sie liefert fuer sie 4 bzw. 5.
  if old.volume_ml is not null
     and new.volume_ml is distinct from old.volume_ml
     and coalesce(account_level(auth.uid()), 0) < 2 then
    raise exception
      'Eine vorhandene Gebindegroesse aendert erst ab Vertrauensstufe 2'
      using errcode = '42501';
  end if;
  return new;
end $$;

comment on function public.beer_barcode_volume_guard() is
  'Fuellen darf jeder, ueberschreiben erst ab Stufe 2 — eine gepruefte '
  'Angabe soll kein Fehltipp ersetzen.';

revoke execute on function public.beer_barcode_volume_guard()
  from public, anon, authenticated;

drop trigger if exists beer_barcodes_volume_guard on public.beer_barcodes;
create trigger beer_barcodes_volume_guard
  before update on public.beer_barcodes
  for each row execute function public.beer_barcode_volume_guard();
