# 15 — Bier in Österreich: Marktlage, Regeln, Datenlage

> **Stand:** 2026-09-05. Zahlen aus einer Recherche zu diesem Datum;
> Marktdaten veralten, Rechtsstand ändert sich. Wer hier eine Zahl
> benutzt, nennt das Jahr dazu.

Kein Funktionsdokument — es beschreibt **das Umfeld, in dem die App
läuft**. Warum das im Repo steht: Mehrere Entscheidungen der App sind
ohne diesen Hintergrund nicht nachvollziehbar (warum Stammwürze ein
eigenes Feld hat, warum bei den Brauereien ein Konzern vermerkt ist,
warum das Pfand beim Gebinde und nicht beim Bier hängt).

---

## 1. Der Markt

Österreich hat, gemessen an der Bevölkerung, eine der höchsten
Brauereidichten der Welt: **347 Braustätten (2023)**, darunter 129
Gasthaus- und Hausbrauereien — fast dreimal so viele wie 2010. Allein
53 davon stehen in der Steiermark.

| Kennzahl | Wert | Jahr |
|---|---|---|
| Gesamtausstoß (inkl. alkoholfrei + Export) | 10,09 Mio. hl (+1,1 %) | 2024 |
| Gesamtausstoß | 9,25 Mio. hl (−7,1 %) | 2025 |
| Inlandsproduktion Bier + alkoholfrei | 7,88 Mio. hl (−6,1 %) | 2025 |
| Export | 1,37 Mio. hl (−12,4 %) | 2025 |
| Pro-Kopf-Konsum | 98,4 l | 2024 |
| Branchenumsatz | > 1,4 Mrd. EUR | 2024 |
| Braustätten (inkl. 129 Gasthaus/Haus) | 347 | 2023 |
| Anteil alkoholfreies Bier am Ausstoß | 3,7 % (> 310.000 hl) | 2024 |
| Sortenanteil Lager/Märzen | ~70 % (≈ 5,5 Mio. hl) | 2024/25 |
| Mehrweg-Anteil Bier | 67 % → 72 % | 2024 → 2025 |
| Anteil 0,5-l-Mehrwegglas am Inlandsausstoß | 46,6 % → 50,7 % | 2024 → 2025 |
| Gebindemix Fass&Tank / Dose / Glas | 17,4 % / 25,8 % / 56,8 % | 2024 |
| Dosenbierproduktion Inland | ~1,7 Mio. hl (−23 %) | 2025 |

Der Pro-Kopf-Wert wird je nach Berechnungsbasis unterschiedlich
angegeben (98,4 l bei Statista/Verband; eine Verbandsmitteilung nennt
vorläufig „ca. 103 l"). Für Vergleiche der niedrigere, belegte Wert.

### Wem gehört was

Sieben Braustätten über 500.000 hl liefern rund drei Viertel des
österreichischen Biers. Die **Brau Union Österreich** (seit 2003
vollständig bei Heineken, Sitz Linz) ist mit über 5,0 Mio. hl das
größte Brauereiunternehmen des Landes und hält rund 60 % Marktanteil
im Lebensmittelhandel; zu ihr gehören Gösser, Puntigamer, Zipfer,
Schwechater, Wieselburger/Kaiser, Villacher, Schladminger, Edelweiss
und der Standort Kaltenhausen.

Größte unabhängige Brauerei ist **Stiegl** (Salzburg, rund 1 Mio. hl,
etwa elf Prozent Marktanteil), danach **Ottakringer** (Wien) — die
letzte große Brauerei im Wiener Stadtgebiet. 2021 gründeten zehn
Privatbrauereien den *Verein der Unabhängigen Privatbrauereien
Österreichs*; zusammen stehen sie für rund 28 % der österreichischen
Bierproduktion.

**Deshalb steht `group_owner` bei jeder Brauerei.** Wer „Gösser trinkt
statt Heineken" sagt, trinkt Heineken — und die Zugehörigkeit ist
nirgends aufs Etikett gedruckt. Die App wertet das nicht; sie schreibt
es hin.

Anhängig ist ein Verfahren der Bundeswettbewerbsbehörde gegen die Brau
Union (Vorwurf: Missbrauch der marktbeherrschenden Stellung gegenüber
der Gastronomie, Geldbußenantrag Juni 2024, im März 2026 aufrecht).

---

## 2. Die Regeln

- **Biersteuer:** bemessen nach Stammwürze, **2 EUR je hl und °Plato**.
  Ein Vollbier mit 12 °P trägt rund 24 EUR/hl, also etwa 8 Cent je
  Halbe — nach Angabe des Bier Guide mehr als das 2,5-fache der
  deutschen Biersteuer. Unabhängige Kleinbrauereien zahlen ermäßigt
  60–90 % des Vollsatzes. **Alkoholfreies Bier (≤ 0,5 % vol) ist
  steuerfrei.**
- **Einwegpfand seit 1.1.2025:** 25 Cent auf Einweg-Kunststoffflaschen
  und Dosen von 0,1–3 l, einheitliches Pfandlogo, zentrale Stelle EWP
  Recycling Pfand Österreich gGmbH. Gastronomie mit Vor-Ort-Konsum ist
  ausgenommen.
- **Mehrwegpfand:** Februar 2025 von 9 auf **20 Cent** je 0,5-l-Flasche
  angehoben — die erste Erhöhung seit vierzig Jahren.
- **Kennzeichnung:** Alkoholgehalt und Allergene (glutenhaltiges
  Getreide) sind verpflichtend.

**Was daraus für die App folgt:** Pfand hängt am **Gebinde**, nicht am
Bier — dieselbe Marke kostet in der Dose 25 und in der Mehrwegflasche
20 Cent Pfand. Genau deshalb liegt die Füllmenge in BrewMates an der
EAN (`barcode_volumes`) und nicht am Bier; ein Pfandfeld gehörte, wenn
es je eines gibt, an dieselbe Stelle.

---

## 3. Was davon in den Daten steht

Aus der Recherche sind drei Dinge in `app/assets/data/` eingeflossen:

1. **`state`, `type`, `group_owner`** bei allen 46 österreichischen
   Brauereien. `type` ist eine grobe Einordnung — `grossbrauerei`,
   `regional`, `craft`, `gasthaus`, `kloster` — und keine Wertung.
   Ein Test (`app/test/community_daten_test.dart`) erzwingt, dass jede
   AT-Brauerei beides hat und nur bekannte Werte benutzt.
2. **`og_plato`** (Stammwürze) bei 20 Kernbieren, dazu vier
   IBU-Werte, die bisher fehlten. Stammwürze ist in Österreich die
   Steuerbemessungsgrundlage und sagt dem Trinkenden grob, wie viel
   Körper zu erwarten ist. Angezeigt wird sie als Chip in der
   Bier-Detailansicht (`11,0 °P`).
3. **Ein fehlender Barcode:** `90129407` (Puntigamer, 0,5-l-Mehrweg).
   Prüfziffer nachgerechnet, Füllmenge hinterlegt.

**Nicht übernommen** wurden Handelspreise. Sie waren eine Momentaufnahme
vom 2026-09-05, sind aktionsabhängig und wären eine Woche später falsch
— eine falsche Zahl in der App ist schlechter als keine.

### Was in den Quellen dünn bleibt

- **EAN/GTIN:** Österreichische Händler veröffentlichen keine EANs auf
  Produktseiten, nur interne Artikelnummern. Der belastbare Weg bleibt
  Open Food Facts plus die Barcodes, die beim Scannen in der App
  zusammenkommen. Acht- und dreizehnstellige Codes stehen gleichwertig
  nebeneinander: Eine GTIN-8 ist auf kleinen Gebinden regulär und wird
  vom Scanner genau so zurückgegeben — sie ist **keine** verkürzte
  GTIN-13, die man auffüllen dürfte.
- **IBU:** bei österreichischen Märzen fast durchgängig unveröffentlicht;
  Werte gibt es meist nur für Pils und Craft.
- **Stammwürze:** bei Brau-Union-Marken nur teils offiziell.
- **EBC, Ausstoß je Braustätte:** praktisch nirgends öffentlich.

### Widersprüche in den Quellen

Wo Recherche und Bestand auseinandergingen, blieb der Bestand stehen —
er stammt von den Herstellerseiten. Betroffen: Fohrenburger Jubiläum
(5,4 vs. 5,5 %), Egger Märzen (5,0 vs. 5,1 %), Schladminger BioZwickl
(5,4 vs. 5,2 %), Trumer Pils (4,9 vs. 5,0 %), Villacher Märzen
(11,8 vs. 11,5 °P). Bei Edelweiss Hefetrüb stand gar kein Wert; dort
sind 5,1 % nachgetragen.

---

## 4. Quellen

Verband und Statistik: bierland-oesterreich.at, WKO Braubilanz 2024/2025,
brauwelt.com, de.statista.com, Statistik Austria. Recht: usp.gv.at,
oesterreich.gv.at, wko.at, bier-guide.net. Markt: de.wikipedia.org,
retailreport.at, nachrichten.at, tastingwithmatze.de. Produktdaten:
Herstellerseiten der genannten Brauereien, bierkreiszeichen.at,
meininger.de, Open Food Facts.

Für die laufende Pflege der Bierdaten gilt weiterhin
[docs/10 — Community-Datenpflege](10-community-datenpflege.md); die
Herkunft der ausgelieferten Datensätze steht in
`app/assets/data/DATENHERKUNFT.md`.
