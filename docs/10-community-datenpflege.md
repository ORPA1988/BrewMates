# Community-Datenpflege: nutzererstellte Biere prüfen

Wenn ein Scan keinen Treffer liefert, legt die App das Bier direkt in
Supabase an (`beers` mit `verified = false`, Migration 0010). Diese
Einträge sind bewusst niederschwellig: Name, Stil, Alkoholgehalt und
Brauerei kommen aus dem Anlegen-Formular — oft unvollständig, weil Open
Food Facts nur „Bier" als Produktnamen kennt oder die Postleitzahl statt
des Orts im Feld landet.

**Routine: bei jedem Entwicklungslauf einmal durchgehen.** Ziel ist eine
Datenbank, in der jeder Eintrag einen echten Produktnamen, einen
plausiblen Stil und — wo bekannt — Alkoholgehalt und Beschreibung hat.

## 1. Offene Einträge auflisten

```sql
select b.id, b.name, b.style, b.abv, b.is_alcohol_free, b.barcode,
       b.description, b.label_url, b.created_at,
       br.id as brewery_id, br.name as brewery, br.city, br.country
from beers b
left join breweries br on br.id = b.brewery_id
where b.verified is not true and not b.hidden
order by b.created_at desc;
```

Verdächtig sind: Name = „Bier"/„Beer"/Marke allein, `abv is null`,
`description is null`, `city` rein numerisch (Postleitzahl), Brauereiname
mit Rechtsform-Kürzeln oder Tippfehlern.

## 2. Fakten beschaffen (in dieser Reihenfolge)

1. **Etikettfoto des Nutzers** — `label_url` zeigt auf den
   `beer-photos`-Bucket. Das Foto ist die verlässlichste Quelle: Name,
   Alkoholgehalt und Stil stehen meist direkt drauf. Bild herunterladen
   und ansehen.
2. **Open Food Facts** über den Barcode:
   `https://world.openfoodfacts.org/api/v2/product/<EAN>.json` — liefert
   Zutaten, Menge, oft den Alkoholgehalt (`nutriments.alcohol_value`)
   und ein Produktfoto.
3. **Web-Recherche** zur Brauerei, wenn Marke und Hersteller auseinander
   liegen (Handels-Eigenmarken werden häufig von Lohnbrauereien gebraut).

Nur übernehmen, was belegt ist. Lieber `null` als geraten — die Felder
sind später jederzeit nachtragbar.

## 3. Eintrag korrigieren und freigeben

```sql
update beers set
  name = '…', style = '…', abv = …, description = '…', verified = true
where id = '…';

update breweries set name = '…', city = '…', country = '…' where id = '…';
```

`verified = true` bedeutet: redaktionell geprüft. Danach greift die
„Kein Bier"-Meldung nicht mehr (Policy `beer_flags_insert`), der Eintrag
ist also vor Community-Löschung geschützt.

**Check-ins nachziehen:** Check-ins speichern Bier- und Brauereinamen
denormalisiert. Nach einer Umbenennung:

```sql
update checkins set beer_name = '…', brewery_name = '…'
where beer_id = '…';
```

## 4. Wirklich falsche Einträge

Kein Bier (Limonade, Fehlscan) und keine Check-ins darauf → löschen.
Hängen Check-ins daran (`ON DELETE RESTRICT`), stattdessen
`hidden = true` setzen; dann verschwindet der Eintrag für alle außer
Admins, ohne fremde Check-ins zu zerstören.

## Kuratierte JSON-Dateien nicht doppeln

Geprüfte Supabase-Einträge **nicht** zusätzlich nach
`app/assets/data/*.json` übertragen: Der Barcode würde dann zweimal
existieren (lokal kuratiert + Supabase-UUID), die Suche zeigte Dubletten,
und die Check-ins der Nutzer hängen an der UUID-Zeile. Die kuratierten
Dateien sind für redaktionell recherchierte Biere ohne
Community-Ursprung reserviert.

## Bisherige Durchläufe

- **2026-08-15** — 2 Einträge geprüft: „Bier" (EAN 90031977) →
  *Zipfer Märzen* (5,0 %, Brauerei Zipf); „Bier" (EAN 4061462752865) →
  *Carista Imported Lager* (4,5 %, Brasserie de Champigneulles), beide
  über das Etikettfoto identifiziert, Orte von Postleitzahl auf Ortsname
  korrigiert, ein Check-in nachgezogen. Ursache zusätzlich im Code
  behoben: generische OFF-Namen werden nicht mehr vorbefüllt
  (`BarcodeLookup.isGenericProductName`).
