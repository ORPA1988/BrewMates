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
-- WAS HIER BEWUSST *NICHT* STEHT: EINE REGEL GEGEN ÜBERSCHREIBEN
--
-- Der erste Entwurf hatte einen zweiten Trigger: „eine vorhandene Größe
-- ändern erst ab Vertrauensstufe 2". Der pgTAP-Test hat ihn erledigt,
-- bevor er live ging — **die Regel gibt es längst**, und zwar besser
-- (0028, nachgesehen in `pg_policy` am 2026-09-05):
--
--   beer_barcodes_update  using (created_by = auth.uid()
--                                or account_level(auth.uid()) >= 2)
--
-- Eine **fremde** Angabe ändert also ohnehin nur Stufe 2 aufwärts. Der
-- Trigger hätte darüber hinaus etwas verboten, das erlaubt sein muss:
-- **die eigene Angabe zu korrigieren.** Wer sich beim Eintragen
-- vertippt, hätte den Fehler stehen lassen müssen.
--
-- Das ist die Lehre aus docs/13, Lehre 1, noch einmal: Eine Annahme über
-- Rechte, die niemand nachgesehen hat — diesmal in die andere Richtung.
-- Nachgesehen hat es der Test.
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
