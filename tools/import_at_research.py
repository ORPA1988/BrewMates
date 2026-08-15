"""Uebernimmt den recherchierten AT-Datensatz in die Community-Dateien.

Bewusst ein Skript und keine Handarbeit: 449 neue Biere lassen sich nicht
von Hand pruefen, und ein nachvollziehbarer Lauf ist wiederholbar, wenn
die Quelle nachgeliefert wird.

Was NICHT uebernommen wird, und warum:

* Bild-URLs. Sie liegen in einer eigenen Datei und zeigen auf
  Brauerei-Webseiten. DATENHERKUNFT.md erlaubt nur Verweise auf Open Food
  Facts (CC-BY-SA); von 459 Bildern haben laut Quelle nur 161 einen
  ausgewiesenen Pressehinweis. Das ist eine Rechtefrage, keine technische.

* Herstellerbeschreibungen. Die Quelle nennt sie "woertliches Zitat".
  Unsere Datenherkunft sagt ausdruecklich: Beschreibungen sind
  Paraphrasen, keine Zitate. Woertliche Uebernahme aendert die
  urheberrechtliche Lage.

* brewmates_score. Ein aggregierter Wert aus mehreren Bewertungsquellen.
  Unser community_rating ist laut Datenherkunft eine redaktionelle
  Schaetzung. Zwei verschiedene Dinge unter einem Namen waeren eine Luege
  ueber die Herkunft.

Uebernommen wird, was eindeutig ist: Biere, Brauereien, Stile, Alkohol -
und vor allem die EANs samt Gebindegroesse.

Aufruf: python tools/import_at_research.py <at_beers_app.json>
"""

import io
import json
import re
import sys
import unicodedata

BEERS = 'app/assets/data/beers-at.json'
BREWERIES = 'app/assets/data/breweries-at.json'


def slug(text):
    s = (text or '').lower()
    for a, b in (('ä', 'ae'), ('ö', 'oe'), ('ü', 'ue'),
                 ('ß', 'ss')):
        s = s.replace(a, b)
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9]+', '-', s).strip('-')


def alkoholfrei(q):
    """Ist das Bier alkoholfrei?

    Die Quelle setzt `alkoholfrei` auch bei GLUTENfreien Bieren und
    einmal bei einem 5-%-Stout - das Kennzeichen wurde dort offenbar
    generisch fuer "frei von etwas" verwendet. Der Alkoholgehalt ist die
    verlaesslichere Angabe, und alkoholfrei heisst im DACH-Raum hoechstens
    0,5 % vol.

    Aufgefallen ist das nicht beim Lesen, sondern weil
    tools/validate_data.dart den Widerspruch meldet.
    """
    abv = q.get('abv')
    if abv is not None and abv > 0.5:
        return False
    return bool(q.get('alkoholfrei'))


def norm(text):
    """Vergleichsform fuer die Frage: ist das dasselbe Bier?"""
    return re.sub(r'[^a-z0-9]', '', slug(text))


def main(quelle):
    neu = json.load(io.open(quelle, encoding='utf-8'))['biere']
    beers_doc = json.load(io.open(BEERS, encoding='utf-8'))
    brew_doc = json.load(io.open(BREWERIES, encoding='utf-8'))

    beers = beers_doc['beers']
    breweries = brew_doc['breweries']
    beer_by_norm = {norm(b['name']): b for b in beers}
    brew_by_norm = {norm(b['name']): b for b in breweries}
    brew_ids = {b['id'] for b in breweries}
    beer_ids = {b['id'] for b in beers}
    belegte = {c for b in beers for c in b.get('barcodes', [])}

    neue_biere = neue_brauereien = ergaenzte_eans = neue_groessen = 0

    for q in neu:
        br = q.get('brauerei') or {}
        br_name = (br.get('name') or br.get('brand') or '').strip()
        if not br_name:
            continue
        marke = br.get('brand') or br_name

        vorhanden = brew_by_norm.get(norm(marke)) or brew_by_norm.get(
            norm(br_name))
        if vorhanden:
            br_id = vorhanden['id']
        else:
            basis = 'at-' + slug(marke)
            br_id, n = basis, 2
            while br_id in brew_ids:
                br_id = '%s-%d' % (basis, n)
                n += 1
            eintrag = {
                'id': br_id,
                'name': br_name,
                'city': br.get('ort') or 'Unbekannt',
                'country': 'Österreich',
                'founded': br.get('gruendung'),
                'website': br.get('website'),
                'ownership': br.get('konzern') or br.get('typ'),
                # Ohne Koordinaten erscheint die Brauerei nicht auf der
                # Karte. Sie zu raten waere schlimmer als sie wegzulassen.
                'data_status': 'Recherchedatensatz AT v2.1.0, ohne Gewähr',
            }
            eintrag = {k: v for k, v in eintrag.items() if v is not None}
            breweries.append(eintrag)
            brew_by_norm[norm(marke)] = eintrag
            brew_ids.add(br_id)
            neue_brauereien += 1

        codes, groessen = [], {}
        for sku in q.get('skus', []):
            ean = (sku.get('ean') or '').strip()
            if not re.fullmatch(r'\d{8}|\d{13}', ean):
                continue
            codes.append(ean)
            if sku.get('volumen_ml'):
                groessen[ean] = int(sku['volumen_ml'])

        da = beer_by_norm.get(norm(q['name']))
        if da is not None:
            for c in codes:
                if c not in da.setdefault('barcodes', []) and c not in belegte:
                    da['barcodes'].append(c)
                    belegte.add(c)
                    ergaenzte_eans += 1
            if groessen:
                ziel = da.setdefault('barcode_volumes', {})
                for k, v in groessen.items():
                    if k in da['barcodes'] and k not in ziel:
                        ziel[k] = v
                        neue_groessen += 1
            continue

        basis = 'at-' + slug(q.get('slug') or q['name'])
        bid, n = basis, 2
        while bid in beer_ids:
            bid = '%s-%d' % (basis, n)
            n += 1
        neu_codes = [c for c in codes if c not in belegte]
        belegte.update(neu_codes)
        eintrag = {
            'id': bid,
            'brewery_id': br_id,
            'name': q['name'],
            'style': q.get('stil') or 'Bier',
            'abv': q.get('abv'),
            'ibu': q.get('ibu'),
            'is_alcohol_free': alkoholfrei(q),
            'barcodes': neu_codes,
        }
        gr = {k: v for k, v in groessen.items() if k in neu_codes}
        if gr:
            eintrag['barcode_volumes'] = gr
            neue_groessen += len(gr)
        beers.append(eintrag)
        beer_ids.add(bid)
        beer_by_norm[norm(q['name'])] = eintrag
        neue_biere += 1

    beers_doc['version'] = beers_doc.get('version', 1) + 1
    brew_doc['version'] = brew_doc.get('version', 1) + 1
    beers_doc['updated'] = brew_doc['updated'] = '2026-08-15'

    io.open(BEERS, 'w', encoding='utf-8').write(
        json.dumps(beers_doc, ensure_ascii=False, indent=2) + '\n')
    io.open(BREWERIES, 'w', encoding='utf-8').write(
        json.dumps(brew_doc, ensure_ascii=False, indent=2) + '\n')

    print('neue Biere:      %d' % neue_biere)
    print('neue Brauereien: %d' % neue_brauereien)
    print('EANs ergaenzt:   %d' % ergaenzte_eans)
    print('Gebindegroessen: %d' % neue_groessen)
    print('Bestand jetzt:   %d Biere, %d Brauereien'
          % (len(beers), len(breweries)))


if __name__ == '__main__':
    main(sys.argv[1])
