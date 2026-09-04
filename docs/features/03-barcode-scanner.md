# 03 Barcode-Scanner

> **Status:** 🟢 fertig — Kamera auf Android/iOS/Web, manuelle Eingabe
> überall.
> **Seit:** 0.3.0 · **Zuletzt geprüft:** 2026-09-04

## Zielsetzung

Der schnellste Weg vom Bier zum Check-in. Ein Barcode ist eindeutig, wo
ein Name mehrdeutig ist — und er erspart das Tippen im Halbdunkel.

## Funktion (Nutzersicht)

1. Kamera auf den Barcode halten (oder EAN eintippen)
2. Treffer → Bestätigung mit Bier, Brauerei und Etikettfoto, dann direkt
   zum Check-in
3. Kein Treffer → Anlegen-Formular, vorbefüllt mit dem, was bekannt ist
4. Der neue Eintrag landet sofort in der gemeinsamen Datenbank und steht
   allen zur Verfügung

## Was eine EAN eigentlich sagt

Eine EAN/GTIN identifiziert **nicht das Bier, sondern die
Handelseinheit**: Produkt plus Verpackung plus Größe. Dieselbe Marke in
0,33-Flasche, 0,5-Dose und als Sixpack tragt drei verschiedene Nummern.

Daraus folgt der ganze Rest dieser Funktion:

- **Ein Bier hat mehrere Barcodes** — deshalb ist `beers.barcodes` eine
  Liste und keine Spalte mit einem Wert.
- **Der Barcode kennt die Größe**, das Bier nicht. Beim Scannen steht sie
  im Check-in deshalb schon drin — lokal in `barcode_volumes` (Drift v14),
  geteilt über `beer_barcodes` (Migration 0028).
- **Eine unbekannte EAN heißt selten „neues Bier"**, meistens „bekanntes
  Bier ohne diesen Code". Deshalb die Lupe beim Anlegen (siehe Funktion
  04): Sie hängt den Code an den vorhandenen Eintrag, statt ein Duplikat
  zu erzeugen. Zwei Einträge für dasselbe Bier würden Bewertungen,
  Abzeichen und Statistik auseinanderreißen.

**Der Server konnte das lange nicht.** `beers.barcode` aus Migration 0010
ist eine einzelne Spalte mit UNIQUE — der zweite Code desselben Biers
hatte schlicht keinen Platz, während die App lokal längst eine Liste
führte. Migration 0028 bringt `beer_barcodes`: eine Zeile je Code, mit
Bier und Größe. Die alte Spalte bleibt, damit Clients vor 0.10.2 weiter
funktionieren — die Lehre aus 0024/0026.

**Und lag dann ein halbes Jahr wirkungslos da.** 0028 legte die Tabelle
an, aber die Lesestelle wurde nie umgestellt: Gesucht wurde weiter über
`beers.barcode`, `beer_barcodes` nur befragt, um die *Gebindegröße*
nachzuschlagen — und zwar erst, nachdem das Bier schon gefunden war.
Jeder nachgetragene Code wurde also gespeichert und beim Suchen
ignoriert. Wer „diesen Code zu einem vorhandenen Bier ergänzen" wählte,
bekam eine Bestätigung, und der nächste Mensch, der genau diese Dose
scannte, fand nichts.

Migration 0030 (2026-08-16) räumt das: Der Bestand aus der Altspalte ist
nach `beer_barcodes` übernommen, Suchen, Bearbeiten und Melden sehen
zuerst dort nach. Die Altspalte wird weiterhin **mitgeschrieben**, damit
die ausgelieferte 0.10.2 das Bier findet; sie fällt in einem eigenen,
späteren Schritt — nie in derselben Migration wie ihr Ersatz.

Das Muster ist inzwischen das dritte seiner Art in diesem Projekt: eine
Sache, die aussieht, als wirke sie, und nichts tut.

Seit 0.10.4 fasst der Client `beers.barcode` nicht mehr an, und seit dem
2026-09-02 **gibt es die Spalte nicht mehr** (0032) — eingespielt, nachdem
der Riegel auf 0.10.4 stand. Für Barcodes gibt es am Server nur noch eine
Wahrheit: `beer_barcodes`. Ein Test allein
hätte es nicht gefunden — die Schreibseite funktionierte ja.

Einschränkung fürs Protokoll: EANs werden nach Jahrzehnten gelegentlich
neu vergeben, und Aktionsware trägt manchmal fremde Codes. Die EAN ist ein
sehr guter Schlüssel — **kein Beweis**.

## Der beste Scanner nützt nichts bei falschen Daten (2026-09-02)

Ein Scan der 0,33-Dose **Gösser NaturRadler** schlug ein Bier der
Starkenberger Brauerei vor. Kein Fehler im Scanner, kein Fehler im
Server: In `beers-at.json` hingen sämtliche EANs des Gösser NaturRadlers
am Eintrag `at-brauerei-naturradler` — dem NaturRadler aus Tarrenz. Beim
Ausbau vom 2026-08-15 waren Produkte aus einer Fremdquelle nach
Produktnamen zugeordnet worden, und „NaturRadler“ heißen eben mehrere.

Der Abgleich der 320 hinterlegten Codes gegen die Produkt- und
Markensuche von Open Food Facts förderte dieselbe Verwechslung mehrfach
zutage:

| EAN | hing an | ist in Wahrheit |
| --- | --- | --- |
| `90288456`, `90288470`, `90288104` … (13 Stück) | Starkenberger NaturRadler | Gösser NaturRadler Zitrone |
| `9120060220673` | Gusswerk Steinbier | Steinbier der Marke „urban keller“ |
| `9120060130415` | Vitzthum Pils | Ötscher Pils, Bruckners Erzbräu |
| `42359739` | Gösser NaturRadler | Naturradler der Marke „Linzer“ |
| `9028800142899` | Zipfer HOPS Zitrone | Zipfer HOPS Grapefruit |
| `9007600306311` | Ottakringer Citrus Radler | Ottakringer Wassermelone Radler |
| `9028800636060` | Edelweiss Hefetrüb | Edelweiss Weizen **alkoholfrei** |

**Und der Code, den der Nutzer eigentlich suchte, fehlte:** die 0,33er
Gösser (`90288456`) war nirgends als 0,33 hinterlegt. Genau deshalb
landete der Scan bei einem Namensvetter.

Die österreichische EAN-Tabelle ist seither vollständig neu gesetzt: 207
Codes, jeder einzeln gegen Open Food Facts belegt, 136 davon mit
Gebindegröße. Sechs Codes stehen bewusst **ohne** Zuordnung da — sie
waren nachweislich falsch, und wohin sie gehören, ist nicht belegbar. Ein
Code ohne Bier führt zum Anlegen-Dialog; ein Code am falschen Bier führt
zu einem falschen Check-in.

`test/community_daten_test.dart` hält das jetzt fest: keine EAN an zwei
Bieren, jede EAN eine gültige GTIN-8 oder GTIN-13 mit Prüfziffer, keine
Gebindegröße ohne zugehörigen Code. Die Prüfziffer allein warf `25227868`
aus dem Bestand — acht Ziffern, aber keine gültige GTIN, also ein
Hauscode aus irgendeinem Regal.

**Was der Test nicht kann:** Er prüft die Form, nicht die Wahrheit. Dass
`90288456` zum Gösser NaturRadler gehört und nicht zum Starkenberger,
weiß keine Regel — das wusste nur der Abgleich gegen eine zweite Quelle.

## Technische Umsetzung

- **Dateien:** `features/scan/scan_screen.dart` (Bedienung),
  `features/scan/barcode_lookup.dart` (Logik, kameralos testbar)
- **Suchreihenfolge:** lokale DB → Supabase-Community-DB → Open Food Facts
  → unbekannt
- **Paket:** `mobile_scanner ^5.2.3`, gepinnt auf die Flutter-3.24-Kette
- **Web:** ZXing liegt als `web/zxing.js` im eigenen Bundle; die
  Script-URL wird in `initState` umgebogen — geladen von unpkg.com
  scheiterte still an VPN und Werbeblockern
- **Web-Auflösung:** `features/scan/kamera/aufloesung*.dart` bittet die
  laufende Kamera um Full HD (siehe unten). Plattform-Weiche wie bei der
  Drift-Verbindung: nativ ein No-op
- **Ein Steuergerät, kein neues je Bild.** Der `MobileScannerController`
  ist ein Feld und wird in `dispose` geschlossen. Vorher entstand er in
  `build()`; `MobileScanner` löst sein `controller`-Feld aber nur einmal
  auf (`late final`), also benutzte der Scanner weiter das erste und
  jedes weitere Bauen ließ ein Gerät zurück, das niemand schließt
- **Wenn die Kamera nicht liefert:** `widgets/kamera_hinweis.dart` als
  `errorBuilder` beider Scanner (Bier und QR). Ohne ihn zeigt
  `mobile_scanner` ein schwarzes Rechteck mit weißem Warndreieck — und
  das sieht bei fehlender Freigabe genauso aus wie bei einer belegten
  Kamera oder auf einem Gerät ohne Kamera

**Generische Namen werden verworfen.** Open Food Facts liefert für viele
Biere schlicht „Bier" als Produktnamen. Wird das übernommen, entstehen
Einträge namens „Bier" — genau das ist passiert.
`isGenericProductName` filtert das heute heraus.

### Warum der EAN-Scanner im Browser nichts erkannte (2026-09-04)

Gemeldet: „Der Scanner öffnet, erkennt aber den EAN nicht bzw. löst beim
Scannen nicht aus.“ Der QR-Scanner derselben App lief im selben Browser.

**Der Befund:** `MobileScannerController` nimmt eine `cameraResolution`
entgegen — der Web-Teil von `mobile_scanner` liest sie **nirgends**.
Nachgeprüft in 5.2.3 (unsere Fassung) und in 6.0.11 (die nächste, die
mit Flutter 3.24 überhaupt auflösbar wäre): `grep cameraResolution
lib/src/web/` findet in beiden **null** Treffer. Der `getUserMedia`-Aufruf
dort setzt ausschließlich `facingMode`. Ein Paket-Upgrade hätte es also
nicht behoben — gut zu wissen, bevor man die gepinnte Toolchain anfasst.

Ohne Vorgabe liefert der Browser seine Voreinstellung, auf Android-Chrome
typischerweise **640×480**. Und hier trennen sich die beiden Scanner:

- Ein **QR-Code** ist zweidimensional und grob; 640×480 ist reichlich.
  Deshalb funktionieren Funktion 22 und der Crew-Beitritt.
- Ein **EAN-13** hat 95 Module nebeneinander. Füllt der Code die halbe
  Bildbreite, bleiben knapp drei Pixel je Modul — und davon frisst jede
  Unschärfe die Hälfte. Der Scanner sieht ein Bild und erkennt nie etwas.

**Die Abhilfe:** Sobald die Kamera läuft, wird dieselbe Videospur um
1920×1080 gebeten (`applyConstraints`, `ideal` statt `exact` — eine
Kamera, die es nicht kann, soll weiterlaufen statt mit
`OverconstrainedError` stehenzubleiben). ZXing berechnet seine
Arbeitsfläche bei jedem Bild neu aus `videoWidth`/`videoHeight` und
übernimmt die neue Größe dadurch von selbst.

**Und die Zahl steht im Bild.** Unter dem Rahmen zeigt der Browser-Scanner
„Kamera 1920×1080“ — was die Kamera *tatsächlich* liefert, nicht was
erbeten wurde. Das ist kein Selbstzweck: Bleibt der Scanner stumm,
unterscheidet genau diese Zahl „die Bitte ist verpufft“ von „auflösend
genug und trotzdem nichts“ — zwei Befunde mit völlig verschiedenen
nächsten Schritten. Ohne sie beginnt die nächste Runde wieder bei null.

⚠️ **Nicht im Browser gegengeprüft.** Eine Kamera lässt sich hier nicht
bedienen; die Analyse ist belegt (die Paketquellen sind eindeutig), die
Wirkung ist es nicht. Sie zeigt sich beim nächsten Scan — und die
Zahl unter dem Rahmen sagt dann, woran man ist.

## Modularität

- **Hängt ab von:** Bierdatenbank (04), Check-ins (02)
- **Wird gebraucht von:** [QR-Freunde](22-freunde-per-qr-code.md) nutzt
  dieselbe Scanner-Infrastruktur
- **Ausbauen:** Route und Bildschirm entfernen, `mobile_scanner` aus
  `pubspec.yaml`. Die Suche über den Namen bleibt vollwertig.

## Plattformen

| Plattform | Kamera | Manuell |
|---|---|---|
| Android / iOS | ✅ | ✅ |
| Web | ✅ (Freigabe nötig) | ✅ |
| Windows / macOS | ❌ kein Desktop-Support im Paket | ✅ |

Ohne Kamera erscheint kein Fehler, sondern direkt das Eingabefeld — der
Bildschirm baut den Scanner auf Desktop gar nicht erst.

**Verweigerte Freigabe ist etwas anderes als fehlende Kamera** und wird
seit 0.10.10 auch anders erklärt (Roadmap-Punkt „Kamera-Hinweise beim
Scannen", Issue #64). Drei Fälle, drei Sätze:

| Fall | Was der Hinweis sagt |
|---|---|
| Freigabe fehlt (App) | „…in den App-Einstellungen unter Berechtigungen" + Knopf **Einstellungen öffnen** |
| Freigabe fehlt (Browser) | „…Schloss-Symbol links neben der Adresse, dann Seite neu laden" — kein Knopf, es gibt dort keine Seite dafür |
| Kamera nicht nutzbar / unklar | Ehrlich benannt statt geraten |

In jedem Fall nennt der Hinweis den **zweiten Weg** (EAN tippen bzw. beim
QR-Scanner die Namenssuche). Ein Hinweis, der nur erklärt, warum etwas
nicht geht, lässt den Menschen dort stehen, wo er steht.

Den Knopf „Einstellungen öffnen" liefert `Geolocator.openAppSettings()` —
das Paket ist ohnehin an Bord und öffnet die Systemseite **der App**,
nicht die des Standorts. Ein zweites Berechtigungspaket wäre bei der auf
Flutter 3.24 gepinnten Toolchain der teurere Weg.

## Skalierung

Der lokale Barcode-Vergleich läuft über eine kommagetrennte Liste je Bier;
bei einigen tausend Bieren gehört das in eine eigene indizierte Tabelle.
Open Food Facts ist auf 10 Suchanfragen je Minute begrenzt — für einzelne
Scans irrelevant, für Massenabgleiche der Grund für die Wartezeiten in
den Pflegeskripten.

## Umsetzungsstatus

Vollständig. Die bekannten Fallstricke — CDN-Abhängigkeit, generische
Namen, mehrdeutige Barcodes — sind behoben. Die Kamera-Auflösung im
Browser ist behoben, aber **noch nicht am Gerät bestätigt** (siehe oben).

## Umsetzungsplan

Nur noch Ausbau: QR-Format für [Funktion 22](22-freunde-per-qr-code.md)
ergänzen; beim ersten Scan die
[Hintergrundgeschichte](21-hintergrundgeschichten.md) anbieten.

## Offene Punkte / Ideen

- Bestätigen, dass der EAN-Scanner im Browser wieder auslöst — und mit
  welcher Auflösung (steht unter dem Rahmen)
- Etikett-Erkennung per Foto, wenn kein Barcode vorhanden ist
- Barcodes je Bier in eine eigene Tabelle statt kommagetrennt
