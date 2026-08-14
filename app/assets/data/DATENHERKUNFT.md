# Datenherkunft

Die Community-Datenbank umfasst acht Dateien: `beers-at.json` und `breweries-at.json` (Österreich, 68 Biere / 34 Brauereien), `beers-by.json` und `breweries-by.json` (Bayern, 72 Biere / 33 Brauereien), `beers-de.json` und `breweries-de.json` (Deutschland ohne Bayern, 95 Biere / 40 Brauereien) sowie `beers-ch.json` und `breweries-ch.json` (Schweiz, 45 Biere / 18 Brauereien). Biere und Brauereien sind über das Feld `brewery_id` miteinander verknüpft.

Die Bier- und Brauereidaten stammen aus dem Trainingswissen eines KI-Modells (Stand ca. 2025) und wurden redaktionell zusammengestellt — ohne Gewähr auf Vollständigkeit oder Richtigkeit einzelner Angaben (z. B. Alkoholgehalt oder Sortimentsstand). Das Feld `community_rating` ist eine konservative redaktionelle Schätzung auf Basis des allgemeinen Rufs der Biere und kein gemessener oder von einer Plattform übernommener Wert. Beschreibungstexte sind Paraphrasen und keine wörtlichen Zitate der Brauereien. Korrekturen und Ergänzungen sind ausdrücklich willkommen — bitte per GitHub-Issue melden.

## Etiketten-Bilder (`image_url`) und Barcodes aus Open Food Facts

Die Felder `image_url` sowie ein Teil der `barcodes`-Einträge (in allen Bier-Dateien) stammen aus [Open Food Facts](https://world.openfoodfacts.org), einer offenen, gemeinschaftlich gepflegten Lebensmitteldatenbank (Abgleich am 2026-08-13 für Österreich/Bayern und am 2026-08-14 für Deutschland/Schweiz über die Such- und Produkt-API von Open Food Facts).

- **Bilder:** Wir speichern keine Bilddateien, sondern verlinken lediglich auf die bei Open Food Facts gehosteten Produktfotos (`images.openfoodfacts.org`). Die Fotos wurden von Open-Food-Facts-Beitragenden hochgeladen und stehen unter der Lizenz [CC-BY-SA](https://creativecommons.org/licenses/by-sa/3.0/deed.de); Urheber sind die jeweiligen Fotografinnen und Fotografen (abrufbar über die Produktseite zum jeweiligen Barcode, z. B. `https://world.openfoodfacts.org/product/<EAN>`).
- **Produktdaten** (z. B. per Abgleich ergänzte EAN-Barcodes) stehen unter der [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/).
- Bilder wurden nur übernommen, wenn das Open-Food-Facts-Produkt eindeutig dem Bier in unserer Liste zugeordnet werden konnte (bei bereits verifizierten Barcodes direkt über die EAN, sonst über eindeutige Produktnamen-Treffer). Da die Daten gemeinschaftlich gepflegt werden, können sich Bild-URLs ändern oder einzelne Zuordnungen fehlerhaft sein — Hinweise bitte per GitHub-Issue.
