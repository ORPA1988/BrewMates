# 10 — Community-Datenpflege: nutzererstellte Biere prüfen

> **Routine bei jedem Entwicklungslauf.** Ziel ist eine Datenbank, in der
> jeder Eintrag **einmal** existiert und einen echten Produktnamen, eine
> zugeordnete Brauerei, einen plausiblen Stil und — wo belegbar —
> Alkoholgehalt und Beschreibung hat.
> **Zuletzt geprüft:** 2026-09-04

Wenn ein Scan keinen Treffer liefert, legt die App das Bier direkt in
Supabase an (`beers` mit `verified = false`, Migration 0010). Diese
Einträge sind bewusst niederschwellig: Name, Stil, Alkoholgehalt und
Brauerei kommen aus dem Anlegen-Formular — oft unvollständig, weil Open
Food Facts nur „Bier" als Produktnamen kennt oder die Postleitzahl statt
des Orts im Feld landet.

**Die Reihenfolge unten ist verbindlich.** Schritt 1 kommt zuerst, weil
eine Dublette, die man erst nach dem Recherchieren bemerkt, zweimal
recherchiert wurde — und weil das Zusammenführen umso teurer wird, je
mehr Check-ins inzwischen an der falschen Zeile hängen.

---

## 1. Zuerst: Gibt es das Bier schon?

Ein Nutzer legt ein Bier an, weil der **Scan** nichts fand. Das heißt
nicht, dass es das Bier nicht gibt — es heißt, dass **dieser EAN** nicht
zugeordnet war. Dieselbe Marke steckt oft längst in der Datenbank, unter
leicht anderem Namen oder mit dem Code der anderen Gebindegröße.

```sql
-- Alle ungeprüften Einträge mit ihren Codes und Check-in-Zahlen.
-- (`beers.barcode` gibt es seit 0032 nicht mehr — Codes stehen in
--  `beer_barcodes`, mehrere je Bier.)
select b.id, b.name, b.style, b.abv, b.is_alcohol_free,
       b.description is not null as hat_text,
       b.label_url,
       br.id as brewery_id, br.name as brauerei, br.city, br.country,
       (select string_agg(bb.ean, ', ') from beer_barcodes bb
         where bb.beer_id = b.id) as eans,
       (select count(*) from checkins c where c.beer_id = b.id) as checkins,
       b.created_at
from beers b
left join breweries br on br.id = b.brewery_id
where b.verified is not true and not b.hidden
order by b.created_at;
```

Für **jeden** dieser Einträge:

```sql
-- Ähnliche Namen, egal ob geprüft oder nicht, egal welche Brauerei.
select b.id, b.name, br.name as brauerei, b.verified, b.hidden,
       (select count(*) from checkins c where c.beer_id = b.id) as checkins
from beers b left join breweries br on br.id = b.brewery_id
where b.name ilike '%' || :suchwort || '%'
order by b.verified desc, b.created_at;

-- Und: Ist der EAN vielleicht schon einem anderen Bier zugeordnet?
select bb.ean, bb.volume_ml, b.name, b.verified
from beer_barcodes bb join beers b on b.id = bb.beer_id
where bb.ean = :ean;
```

**Ist es eine Dublette:** nicht löschen, sondern **zusammenführen**. Die
Zeile mit den meisten Check-ins (oder die geprüfte) gewinnt.

```sql
-- 1. Codes umhängen (der neue EAN ist meist die andere Gebindegröße —
--    genau dafür gibt es beer_barcodes seit 0028).
update beer_barcodes set beer_id = :bleibt where beer_id = :geht;
-- 2. Check-ins umhängen, sonst blockiert ON DELETE RESTRICT.
update checkins set beer_id = :bleibt where beer_id = :geht;
-- 3. Die leere Zeile entfernen.
delete from beers where id = :geht;
```

Danach die denormalisierten Namen nachziehen (Schritt 4).

**Achtung, umgekehrter Fall:** Zwei Biere derselben Brauerei mit
ähnlichem Namen sind oft **keine** Dublette (Märzen ≠ Zwickl ≠ Radler).
Im Zweifel getrennt lassen — ein zu Unrecht zusammengeführtes Paar
zerstört fremde Check-ins, eine übersehene Dublette ist nur unschön.

## 2. Fakten beschaffen — beide Quellen, in dieser Reihenfolge

Nur übernehmen, was belegt ist. **Lieber `null` als geraten**; die Felder
sind jederzeit nachtragbar, eine falsche Zahl aber wandert über
`checkins` in fremde Statistiken.

1. **Etikettfoto des Nutzers** (`label_url`, Bucket `beer-photos`). Die
   verlässlichste Quelle: Name, Alkoholgehalt und oft der Stil stehen
   direkt drauf.
2. **Herstellerseite.** Verbindlich für Stil, Stammwürze, Alkoholgehalt
   und einen brauchbaren Beschreibungstext — und die einzige Quelle, die
   sagt, wie die Brauerei sich selbst nennt. Open Food Facts hat hier oft
   Marken- statt Herstellernamen.
3. **Open Food Facts** über den EAN:
   `https://world.openfoodfacts.org/api/v2/product/<EAN>.json`.
   Liefert Gebindegröße (→ `beer_barcodes.volume_ml`), teils den
   Alkoholgehalt (`nutriments.alcohol_value`) und ein Produktfoto.
   **Bilder nur verlinken, nie kopieren** (CC-BY-SA, siehe
   `DATENHERKUNFT.md`).
4. **Web-Recherche**, wenn Marke und Hersteller auseinanderliegen —
   Handels-Eigenmarken werden häufig von Lohnbrauereien gebraut.

**Beide Hauptquellen ansehen, nicht nur die erste, die etwas liefert.**
Open Food Facts ist Crowd-Daten und im Alkoholgehalt oft ungenau; die
Herstellerseite kennt dafür die Gebindegröße dieses EANs meist nicht.
Widersprechen sie sich, gewinnt der Hersteller.

## 3. Brauerei prüfen — nicht nur das Bier

Ein Bier ohne Brauerei ist ein halber Eintrag. Vor dem Freigeben:

```sql
select id, name, city, country,
       (select count(*) from beers where brewery_id = breweries.id) as biere
from breweries
where name is null or name = '' or city ~ '^[0-9]+$' or country = ''
order by name;
```

Verdächtig sind: leerer Name, `city` rein numerisch (Postleitzahl im
falschen Feld), Rechtsform-Kürzel im Namen, Dubletten mit Tippfehlern.
Brauerei-Dubletten werden wie Bier-Dubletten zusammengeführt
(`update beers set brewery_id = …`, dann die leere Zeile löschen).

## 4. Eintrag korrigieren und freigeben

```sql
update beers set
  name = '…', style = '…', abv = …, description = '…',
  is_alcohol_free = false, verified = true
where id = '…';

update breweries set name = '…', city = '…', country = '…' where id = '…';

-- Gebindegröße nachtragen, wenn Open Food Facts sie kennt:
update beer_barcodes set volume_ml = 500 where ean = '…';
```

`verified = true` heißt: redaktionell geprüft. Danach greift die
„Kein Bier"-Meldung nicht mehr (Policy `beer_flags_insert`), der Eintrag
ist also vor Community-Löschung geschützt.

**Check-ins nachziehen — immer.** Sie speichern Bier- und Brauereinamen
denormalisiert; ohne diesen Schritt zeigt der Feed weiter den alten Namen:

```sql
update checkins set beer_name = '…', brewery_name = '…'
where beer_id = '…';
```

## 5. Wirklich falsche Einträge

Kein Bier (Limonade, Fehlscan) und keine Check-ins darauf → löschen.
Hängen Check-ins daran (`ON DELETE RESTRICT`), stattdessen
`hidden = true` setzen; dann verschwindet der Eintrag für alle außer
Admins, ohne fremde Check-ins zu zerstören.

## 6. Wohin gehört der Eintrag? Die Brauerei entscheidet

Es gibt zwei Speicher, und ein Bier darf nur in einem stehen:

- **Kuratierte JSON-Dateien** (`app/assets/data/`) — reisen mit der App,
  funktionieren offline, sind in der App read-only. Die App holt sie bei
  jedem Start frisch von `raw.githubusercontent.com` (Branch `main`);
  **eine Änderung dort erreicht die Geräte also ohne Release.**
- **Supabase** (`beers`, `breweries`) — was Nutzer beim Scannen anlegen.

**Die Regel: Ist die Brauerei bereits kuratiert, gehört das Bier in die
kuratierte Datei.** Sonst steht dieselbe Brauerei zweimal in der Liste —
einmal als kuratierte Zeile, einmal als Supabase-Zeile —, und der Mensch
sieht zwei „Neufeldner", zwischen denen er nicht unterscheiden kann.

| Fall | Wohin |
|---|---|
| Bier steht schon kuratiert | **EAN dort ergänzen**, Supabase-Zeile löschen |
| Brauerei kuratiert, Bier nicht | Bier in der kuratierten Datei **anlegen**, Supabase-Zeile löschen |
| Brauerei nicht kuratiert (oder außerhalb DACH) | Bleibt in Supabase, dort vervollständigen und `verified = true` |

**Nie kopieren, immer verschieben.** Steht ein EAN in beiden Speichern,
zeigt die Suche Dubletten — und die Check-ins der Nutzer hängen an der
Supabase-UUID, nicht an der kuratierten ID.

Beim Einfügen in eine JSON-Datei: **nicht sortieren.** Die Dateien sind
nach Brauerei gruppiert, nicht nach ID geordnet; ein `sort()` erzeugt
einen 1700-Zeilen-Diff für einen Eintrag. Neben die anderen Biere
derselben Brauerei einfügen, `version` hochzählen und `updated` setzen.

---

## Bisherige Durchläufe

- **2026-08-15** — 2 Einträge: „Bier" (EAN 90031977) → *Zipfer Märzen*
  (5,0 %, Brauerei Zipf); „Bier" (EAN 4061462752865) → *Carista Imported
  Lager* (4,5 %, Brasserie de Champigneulles). Beide über das Etikettfoto
  identifiziert, Orte von Postleitzahl auf Ortsname korrigiert, ein
  Check-in nachgezogen. Ursache zusätzlich im Code behoben: generische
  OFF-Namen werden nicht mehr vorbefüllt
  (`BarcodeLookup.isGenericProductName`).

- **2026-09-04** — 5 offene Einträge, davon **drei Dubletten**. Der
  Dublettencheck war neu und hat sich sofort bezahlt gemacht:
  - *Baumgartner Märzen* stand längst in `beers-at.json` — **mit exakt
    demselben EAN** (90147159). Der Scan war älter als die kuratierte
    Zeile; Supabase-Eintrag gelöscht.
  - *„Neufeldner"* (ohne Sorte, ohne Brauerei) ist der **Neufeldner
    Märzen**: Von den sieben kuratierten Neufeldner-Bieren hat genau
    eines 4,6 % — den Wert, den der Nutzer eingetragen hatte. EAN
    9120050021655 in `beers-at.json` ergänzt, Supabase-Eintrag gelöscht.
    Bei der Gelegenheit die **Alkoholgehalte aller sieben** von
    biobrauerei.at nachgetragen (standen auf `null`).
  - *Mönchshof Kellerbier*: Die Brauerei (Kulmbacher) war kuratiert, das
    Bier nicht — neu in `beers-by.json`, Supabase-Eintrag gelöscht.
    Daran hing eine „Kein Bier"-Meldung, offenbar aus Ärger über den
    unvollständigen Eintrag; sie ist mit ihm gegangen.
  - *Corona Extra* (nicht DACH) und *Bier Aktien Zwick'l* (Brauerei nicht
    kuratiert) bleiben in Supabase und sind dort vervollständigt: Corona
    hatte die **Marke statt des Herstellers** als Brauerei und „Österreich"
    als Land (jetzt Cervecería Modelo, Mexiko, Lager, 4,5 %, 355 ml); das
    Zwick'l war als „Helles" eingetragen, obwohl der Name Kellerbier sagt
    (jetzt Kellerbier, 5,3 %, 500 ml, Bayreuth).

  Danach: **null ungeprüfte Einträge**, keine Brauerei ohne Namen, keine
  Postleitzahl im Ortsfeld.
