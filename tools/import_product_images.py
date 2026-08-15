"""Traegt Produktfotos der Brauereien in die Bier-Dateien ein.

Bisher galt: Bilder nur als Verweis auf Open Food Facts. Die Brauereien
zeigen ihre Produkte aber selbst - in besserer Qualitaet und vollstaendiger.
Auf Entscheidung des Projektinhabers werden diese Fotos verlinkt.

DAHER DIE PFLICHTANGABE: Jedes Bild bekommt seine Quellseite mit
(`image_source`), und wo die Brauerei einen Nutzungshinweis ausweist, auch
den (`image_license`). Die App zeigt beides beim Bier an.

Das ist kein Formalismus. Ein fremdes Produktfoto ohne Herkunftsangabe zu
zeigen ist der Unterschied zwischen Zitieren und Nehmen - und
`tools/validate_data.dart` laesst ein Bild ohne Quelle deshalb nicht durch.

Wir speichern weiterhin KEINE Bilddateien, sondern verlinken nur.

Aufruf: python tools/import_product_images.py <at_produktbilder.json>
"""

import io
import json
import re
import sys
import unicodedata

BEERS = 'app/assets/data/beers-at.json'


def norm(text):
    s = (text or '').lower()
    for a, b in (('ä', 'ae'), ('ö', 'oe'), ('ü', 'ue'), ('ß', 'ss')):
        s = s.replace(a, b)
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9]', '', s)


def main(quelle):
    bilder = json.load(io.open(quelle, encoding='utf-8'))
    doc = json.load(io.open(BEERS, encoding='utf-8'))
    beers = doc['beers']
    nach_name = {norm(b['name']): b for b in beers}

    gesetzt = uebersprungen = ohne_treffer = ohne_quelle = 0

    for bild in bilder:
        url = (bild.get('bild_url') or '').strip()
        quellseite = (bild.get('quelle') or '').strip()
        if not url.startswith('https://'):
            # Nur https: Ein http-Bild blockiert der Browser in der
            # Web-App als "mixed content", und in der App ist es
            # unverschluesselt unterwegs.
            continue
        if not quellseite:
            ohne_quelle += 1
            continue

        ziel = nach_name.get(norm(bild.get('bier')))
        if ziel is None:
            ohne_treffer += 1
            continue
        if ziel.get('image_url'):
            # Vorhandenes nicht ueberschreiben: Die bestehenden Bilder
            # stammen aus dem geprueften Open-Food-Facts-Abgleich.
            uebersprungen += 1
            continue

        ziel['image_url'] = url
        ziel['image_source'] = quellseite
        hinweis = (bild.get('lizenzhinweis') or '').strip()
        if hinweis:
            ziel['image_license'] = hinweis
        gesetzt += 1

    doc['version'] = doc.get('version', 1) + 1
    doc['updated'] = '2026-08-15'
    io.open(BEERS, 'w', encoding='utf-8').write(
        json.dumps(doc, ensure_ascii=False, indent=2) + '\n')

    mit_bild = sum(1 for b in beers if b.get('image_url'))
    print('Bilder gesetzt:        %d' % gesetzt)
    print('bereits belegt:        %d' % uebersprungen)
    print('kein passendes Bier:   %d' % ohne_treffer)
    print('ohne Quellseite:       %d' % ohne_quelle)
    print('Biere mit Bild jetzt:  %d von %d' % (mit_bild, len(beers)))


if __name__ == '__main__':
    main(sys.argv[1])
