-- 0032: `beers.barcode` entfernen.
--
-- ============================================================================
-- ⚠️ ERST EINSPIELEN, WENN KEIN CLIENT VOR 0.10.4 MEHR ZUGREIFT.
--
-- 0.10.3 und aelter selektieren die Spalte noch in `communityBeerByBarcode`
-- (`select '…, barcode, …'`). Faellt sie, scheitert dort die **gesamte**
-- Abfrage — der Scanner findet am Server nichts mehr, wortlos. Der Riegel
-- `min_supported_version` erreicht diese Fassungen (ab 0.10.2 ja), also:
-- zuerst `min_supported_version` auf 0.10.4 heben, dann diese Datei.
--
-- Getrennt von 0030, das die Ersatzschnittstelle brachte — die Lehre aus
-- 0024/0026: Ein Entzug gehoert nie in dieselbe Datei wie der Ersatz.
-- ============================================================================
-- WARUM UEBERHAUPT
--
-- Zwei Wahrheiten ueber denselben Sachverhalt. `beers.barcode` (ein Code je
-- Bier, unique) und `beer_barcodes` (beliebig viele, mit Gebindegroesse)
-- wurden von verschiedenen Codepfaden beschrieben und liefen auseinander.
-- Genau daran lag es, dass nachgetragene Codes ein halbes Jahr wirkungslos
-- waren (0030). Solange die Altspalte existiert, kann das wieder passieren.
-- ============================================================================

-- Sicherheitsnetz: Nichts darf verloren gehen, was nur hier stand.
-- (0030 hat bereits uebernommen; das hier faengt, was seither dazukam.)
insert into beer_barcodes (ean, beer_id)
select b.barcode, b.id from beers b where b.barcode is not null
on conflict (ean) do nothing;

-- Die Meldefunktion kennt die Altspalte nicht mehr.
create or replace function public.flag_beer_by_barcode(p_barcode text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_beer_id uuid;
begin
  if auth.uid() is null then
    return false;
  end if;
  select b.id into v_beer_id
    from beers b
    join beer_barcodes bb on bb.beer_id = b.id
   where bb.ean = p_barcode and not b.verified and not b.hidden
   limit 1;
  if v_beer_id is null then
    return false;
  end if;
  insert into beer_flags (beer_id, profile_id)
  values (v_beer_id, auth.uid())
  on conflict do nothing;
  return found;
end $$;
revoke execute on function public.flag_beer_by_barcode(text) from public, anon;
grant execute on function public.flag_beer_by_barcode(text) to authenticated;

alter table beers drop column if exists barcode;
