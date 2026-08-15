# Datenherkunft

Die Community-Datenbank umfasst acht Dateien: `beers-at.json` und `breweries-at.json` (Österreich, 68 Biere / 34 Brauereien), `beers-by.json` und `breweries-by.json` (Bayern, 72 Biere / 33 Brauereien), `beers-de.json` und `breweries-de.json` (Deutschland ohne Bayern, 95 Biere / 40 Brauereien) sowie `beers-ch.json` und `breweries-ch.json` (Schweiz, 45 Biere / 18 Brauereien). Biere und Brauereien sind über das Feld `brewery_id` miteinander verknüpft.

Die Bier- und Brauereidaten stammen aus dem Trainingswissen eines KI-Modells (Stand ca. 2025) und wurden redaktionell zusammengestellt — ohne Gewähr auf Vollständigkeit oder Richtigkeit einzelner Angaben (z. B. Alkoholgehalt oder Sortimentsstand). Das Feld `community_rating` ist eine konservative redaktionelle Schätzung auf Basis des allgemeinen Rufs der Biere und kein gemessener oder von einer Plattform übernommener Wert. Beschreibungstexte sind Paraphrasen und keine wörtlichen Zitate der Brauereien. Korrekturen und Ergänzungen sind ausdrücklich willkommen — bitte per GitHub-Issue melden.

## Ausbau Österreich, 2026-08-15

Der österreichische Bestand wuchs von 68 auf 487 Biere und von 34 auf 71
Brauereien. Grundlage ist ein eigens recherchierter Referenzdatensatz
(„Bier-Stammdaten Österreich v2.1.0"), übernommen über
`tools/import_at_research.py` — als Skript, damit der Lauf nachvollziehbar
und wiederholbar bleibt.

**Neu dabei sind 113 Gebindegrößen je Barcode** (`barcode_volumes`). Eine
EAN bezeichnet die Handelseinheit, nicht das Getränk: Dieselbe Marke in
0,33 und 0,5 trägt zwei Nummern. Beim Scannen steht die Menge dadurch
schon im Check-in.

### Was bewusst NICHT übernommen wurde

- **Produktbilder.** Die Quelle liefert 459 URLs von Brauerei-Webseiten;
  nur 161 davon tragen einen ausgewiesenen Pressehinweis. Hier gilt
  weiterhin die Regel oben: Bilder werden nur von Open Food Facts
  verlinkt. Eine Übernahme wäre mit den Brauereien zu klären.
- **Herstellerbeschreibungen.** Die Quelle bezeichnet sie als wörtliches
  Zitat. Dieses Dokument sagt seit jeher, dass Beschreibungen Paraphrasen
  sind — eine wörtliche Übernahme änderte die urheberrechtliche Lage.
- **Der „BrewMates-Score" der Quelle.** Ein aggregierter Wert aus mehreren
  Bewertungsquellen. Unser `community_rating` ist eine redaktionelle
  Schätzung. Dasselbe Feld mit zwei Bedeutungen zu füllen wäre eine Lüge
  über die Herkunft.

### Zwei Dinge, die beim Import auffielen

Die Quelle markierte drei Biere als **alkoholfrei**, die es nicht sind —
zwei glutenfreie und einen Stout mit 5,0 % vol. Das Kennzeichen wurde dort
offenbar generisch für „frei von etwas" verwendet. Der Import richtet sich
deshalb nach dem Alkoholgehalt (alkoholfrei = höchstens 0,5 % vol).
Gefunden hat das nicht das Lesen, sondern `tools/validate_data.dart`.

Die 37 neuen Brauereien brachten **keine Koordinaten** mit. Sie wurden über
Nominatim/OpenStreetMap (ODbL) nachgetragen — allerdings nur auf
**Ortsebene**, weil Nominatim die Brauereinamen nicht auflöst. Das steht
so in ihrem `data_status`: Die Markierung zeigt den Ort, nicht die
Braustätte. Eine erfundene Hausadresse wäre schlimmer als eine
gekennzeichnete Näherung.

## Produktfotos der Brauereien (seit 2026-08-15)

Neben den Open-Food-Facts-Bildern verlinkt die App jetzt auch
**Produktfotos von den Brauerei-Webseiten** — 303 Stück, Entscheidung des
Projektinhabers. Sie sind meist vollständiger und in besserer Qualität als
Nutzerfotos.

**Jedes dieser Bilder trägt seine Quelle mit:** `image_source` nennt die
Seite, von der es stammt, und wo die Brauerei einen Nutzungshinweis
ausweist, steht er in `image_license` (192 der 448 Bilder der Quelle).
Die App zeigt beides unter dem Bild an.

Erzwungen wird das an zwei Stellen: `tools/validate_data.dart` lässt ein
Bild von einer fremden Seite ohne `image_source` nicht durch, und
`test/bild_herkunft_test.dart` prüft denselben Punkt auf dem echten
Bestand. Ein fremdes Produktfoto ohne Herkunftsangabe zu zeigen ist der
Unterschied zwischen Zitieren und Nehmen.

Wie bisher gilt: **Wir speichern keine Bilddateien, wir verlinken nur.**
Ändert eine Brauerei ihre Seite, verschwindet das Bild — die App zeigt
dann wieder das Krug-Symbol.

Wer eine Veröffentlichung über den internen Gebrauch hinaus plant, sollte
die Nutzung mit den Brauereien klären; ergiebige Pressebereiche mit
freigegebenen Packshots nennt der Recherchedatensatz ausdrücklich
(u. a. Ottakringer, Zwettler, Egger, Stiegl, Murauer, Freistädter).

## Etiketten-Bilder (`image_url`) und Barcodes aus Open Food Facts

Die Felder `image_url` sowie ein Teil der `barcodes`-Einträge (in allen Bier-Dateien) stammen aus [Open Food Facts](https://world.openfoodfacts.org), einer offenen, gemeinschaftlich gepflegten Lebensmitteldatenbank (Abgleich am 2026-08-13 für Österreich/Bayern und am 2026-08-15 für Deutschland/Schweiz über die Such- und Produkt-API von Open Food Facts). Für Deutschland und die Schweiz wurde jede einzelne Zuordnung anschließend über die Produkt-API gegengeprüft (Brauerei, Namensbestandteile, Alkoholfrei-Status); mehrdeutige Treffer wurden verworfen, weil ein falscher Barcode den Scanner auf das falsche Bier führen würde. Brauereien ohne belegte Koordinaten wurden über [Nominatim/OpenStreetMap](https://nominatim.openstreetmap.org) geokodiert (ODbL).

- **Bilder:** Wir speichern keine Bilddateien, sondern verlinken lediglich auf die bei Open Food Facts gehosteten Produktfotos (`images.openfoodfacts.org`). Die Fotos wurden von Open-Food-Facts-Beitragenden hochgeladen und stehen unter der Lizenz [CC-BY-SA](https://creativecommons.org/licenses/by-sa/3.0/deed.de); Urheber sind die jeweiligen Fotografinnen und Fotografen (abrufbar über die Produktseite zum jeweiligen Barcode, z. B. `https://world.openfoodfacts.org/product/<EAN>`).
- **Produktdaten** (z. B. per Abgleich ergänzte EAN-Barcodes) stehen unter der [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/).
- Bilder wurden nur übernommen, wenn das Open-Food-Facts-Produkt eindeutig dem Bier in unserer Liste zugeordnet werden konnte (bei bereits verifizierten Barcodes direkt über die EAN, sonst über eindeutige Produktnamen-Treffer). Da die Daten gemeinschaftlich gepflegt werden, können sich Bild-URLs ändern oder einzelne Zuordnungen fehlerhaft sein — Hinweise bitte per GitHub-Issue.

## Hintergrundgeschichten (`story`)

Das Feld `story` enthält eine kurze Hintergrundgeschichte zur Brauerei
bzw. zum Bier — zwei bis fünf Sätze, redaktionell in eigenen Worten
formuliert. Übernommen werden nur Angaben, die allgemein bekannt und gut
belegt sind (Gründungsjahre, Eigentumsverhältnisse, historische
Besonderheiten); unsichere Superlative sind als Anspruch gekennzeichnet
(„gilt als", „nach eigener Zählung") und nicht als Tatsache.

Es sind **keine wörtlichen Übernahmen** von Brauerei-Webseiten,
Wikipedia-Artikeln oder anderen Texten. Zahlen und Jahreszahlen dürfen
aus öffentlichen Quellen stammen, die Formulierungen sind unsere.

Es gilt dieselbe Regel wie für den übrigen Bestand, hier aber besonders
streng: **lieber kein Eintrag als ein erfundener.** Eine plausibel
klingende, aber falsche Brauereigeschichte ist schlimmer als eine leere
Fläche — sie wird geglaubt und weitererzählt. Brauereien ohne gesicherte
Geschichte haben deshalb kein `story`-Feld; die Anzeige lässt den
Abschnitt dann weg.

Stand: 30 Brauereien (Österreich und Bayern) und 1 Bier haben eine
Geschichte. Korrekturen und Ergänzungen bitte per GitHub-Issue.
