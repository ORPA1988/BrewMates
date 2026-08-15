"""Ergaenzt fehlende Brauerei-Koordinaten ueber Nominatim (OpenStreetMap).

Warum ueberhaupt: Ohne Koordinaten fehlt eine Brauerei auf der Karte -
`data_layer_test.dart` haelt das als Zusicherung fest.

WICHTIG, und darum steht es auch im `data_status` jeder betroffenen Zeile:
Nominatim findet die Brauerei-NAMEN nicht, nur die Orte. Die Position ist
also der Ortsmittelpunkt, nicht die Braustaette. Fuer eine Uebersichtskarte
taugt das; wer davor steht, steht nicht vor der Brauerei.

Eine erfundene Hausadresse waere schlimmer - deshalb die Kennzeichnung
statt einer Scheingenauigkeit.

Nominatim erlaubt eine Anfrage pro Sekunde und verlangt einen echten
User-Agent. Beides haelt dieses Skript ein (ODbL, siehe DATENHERKUNFT.md).

Aufruf: python tools/geocode_breweries.py [datei ...]
"""

import io
import json
import sys
import time
import urllib.parse
import urllib.request

AGENT = 'BrewMates/0.10.2 (github.com/ORPA1988/BrewMates)'
HINWEIS = 'Position auf Ortsebene (Nominatim/OSM), nicht die Braustätte'


def suche(text):
    url = ('https://nominatim.openstreetmap.org/search?q=%s&format=json&limit=1'
           % urllib.parse.quote(text))
    req = urllib.request.Request(url, headers={'User-Agent': AGENT})
    try:
        treffer = json.load(urllib.request.urlopen(req, timeout=20))
    except Exception as fehler:                      # noqa: BLE001
        print('  Fehler bei "%s": %s' % (text, fehler))
        return None
    if not treffer:
        return None
    return float(treffer[0]['lat']), float(treffer[0]['lon'])


def main(dateien):
    for datei in dateien:
        doc = json.load(io.open(datei, encoding='utf-8'))
        offen = [b for b in doc['breweries']
                 if b.get('latitude') is None or b.get('longitude') is None]
        print('%s: %d ohne Position' % (datei, len(offen)))

        gefunden = 0
        for b in offen:
            teile = [b.get('city'), b.get('country')]
            frage = ', '.join(t for t in teile if t and t != 'Unbekannt')
            if not frage:
                print('  %s: kein Ort hinterlegt, uebersprungen' % b['id'])
                continue
            pos = suche(frage)
            time.sleep(1.2)                          # Nominatim: 1 Anfrage/s
            if pos is None:
                print('  %s: nichts gefunden (%s)' % (b['id'], frage))
                continue
            b['latitude'], b['longitude'] = pos
            vorher = b.get('data_status')
            b['data_status'] = (
                '%s; %s' % (vorher, HINWEIS) if vorher else HINWEIS)
            gefunden += 1

        if gefunden:
            doc['version'] = doc.get('version', 1) + 1
            io.open(datei, 'w', encoding='utf-8').write(
                json.dumps(doc, ensure_ascii=False, indent=2) + '\n')
        print('  ergaenzt: %d' % gefunden)


if __name__ == '__main__':
    main(sys.argv[1:] or ['app/assets/data/breweries-at.json'])
