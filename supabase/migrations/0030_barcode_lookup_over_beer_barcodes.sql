-- 0030: Barcode-Suche auf `beer_barcodes` umstellen (ohne zu entziehen).
--
-- ============================================================================
-- DER FEHLER
--
-- 0028 hat `beer_barcodes` eingeführt, weil `beers.barcode` genau **einen**
-- EAN je Bier halten kann (die Spalte ist `unique`). Eine EAN bezeichnet
-- aber die Handelseinheit: Dieselbe Marke in 0,33 und 0,5 trägt zwei
-- Nummern, das Sixpack eine dritte.
--
-- Nur wurde die Lesestelle nie umgestellt. `beer_barcodes` wird bis heute
-- ausschließlich abgefragt, um die **Gebindegröße** nachzuschlagen — und
-- zwar erst, nachdem das Bier bereits gefunden wurde. Gefunden wird es
-- über `beers.barcode`.
--
-- Folge: Jeder nachgetragene Barcode wird gespeichert und ist wirkungslos.
-- Wer in der App „diesen Code zu einem vorhandenen Bier ergänzen" wählt,
-- bekommt eine Bestätigung, und der nächste Mensch, der genau diese Dose
-- scannt, findet nichts. Das ist die teuerste Sorte Fehler: Die Funktion
-- meldet Erfolg und tut nichts.
--
-- ============================================================================
-- WAS HIER PASSIERT — UND WAS BEWUSST NICHT
--
-- Diese Migration **entzieht nichts**. `beers.barcode` bleibt bestehen und
-- gefüllt. Sie macht `beer_barcodes` nur vollständig und lehrt die
-- Serverfunktion, dort nachzusehen.
--
-- Das Entfernen von `beers.barcode` ist ein eigener, späterer Schritt.
-- Grund ist die Lehre aus 0024/0026, die dieses Projekt teuer bezahlt hat:
-- Eine Migration, die etwas entzieht, gehört nie in dieselbe Datei wie die
-- Ersatzschnittstelle — sonst gibt es kein Zeitfenster, in dem alter und
-- neuer Client zugleich funktionieren. Hier ist der „alte Client" die
-- ausgelieferte 0.10.2, die weiterhin `beers.barcode` liest.
-- ============================================================================

-- Alles, was bisher nur in der Altspalte stand, kommt herüber. `on conflict
-- do nothing`, weil derselbe EAN dort bereits stehen kann — dann gilt der
-- neuere Eintrag mit seiner Gebindegröße.
insert into beer_barcodes (ean, beer_id)
select b.barcode, b.id
  from beers b
 where b.barcode is not null
on conflict (ean) do nothing;

-- Die Meldefunktion sieht ab jetzt in beiden Quellen nach.
--
-- Der Zweig über `beers.barcode` ist Übergang, nicht Absicht: Solange
-- ausgelieferte Clients neue Biere noch mit der Altspalte anlegen, muss
-- ein so eingetragener Code meldbar bleiben. Er faellt mit der Spalte.
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
   where not b.verified
     and not b.hidden
     and (
       b.id = (select bb.beer_id from beer_barcodes bb where bb.ean = p_barcode)
       or b.barcode = p_barcode
     )
   limit 1;

  if v_beer_id is null then
    return false;
  end if;

  insert into beer_flags (beer_id, profile_id)
  values (v_beer_id, auth.uid())
  on conflict do nothing;
  return found;
end $$;

-- Seit 0008 gilt: EXECUTE wird von PUBLIC entzogen und gezielt gewährt.
-- `create or replace` erhält die bestehende ACL; das hier steht trotzdem
-- da, damit die Datei aus sich heraus vollständig ist und ein
-- From-scratch-Aufbau nicht von der Reihenfolge abhängt.
revoke execute on function public.flag_beer_by_barcode(text) from public, anon;
grant execute on function public.flag_beer_by_barcode(text) to authenticated;
