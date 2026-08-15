# 03 Barcode-Scanner

> **Status:** 🟢 fertig — Kamera auf Android/iOS/Web, manuelle Eingabe
> überall.
> **Seit:** 0.3.0 · **Zuletzt geprüft:** 2026-08-15

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

## Technische Umsetzung

- **Dateien:** `features/scan/scan_screen.dart` (Bedienung),
  `features/scan/barcode_lookup.dart` (Logik, kameralos testbar)
- **Suchreihenfolge:** lokale DB → Supabase-Community-DB → Open Food Facts
  → unbekannt
- **Paket:** `mobile_scanner ^5.2.3`, gepinnt auf die Flutter-3.24-Kette
- **Web:** ZXing liegt als `web/zxing.js` im eigenen Bundle; die
  Script-URL wird in `initState` umgebogen — geladen von unpkg.com
  scheiterte still an VPN und Werbeblockern

**Generische Namen werden verworfen.** Open Food Facts liefert für viele
Biere schlicht „Bier" als Produktnamen. Wird das übernommen, entstehen
Einträge namens „Bier" — genau das ist passiert.
`isGenericProductName` filtert das heute heraus.

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

Ohne Kamera erscheint kein Fehler, sondern direkt das Eingabefeld.

## Skalierung

Der lokale Barcode-Vergleich läuft über eine kommagetrennte Liste je Bier;
bei einigen tausend Bieren gehört das in eine eigene indizierte Tabelle.
Open Food Facts ist auf 10 Suchanfragen je Minute begrenzt — für einzelne
Scans irrelevant, für Massenabgleiche der Grund für die Wartezeiten in
den Pflegeskripten.

## Umsetzungsstatus

Vollständig. Die drei bekannten Fallstricke — CDN-Abhängigkeit,
generische Namen, mehrdeutige Barcodes — sind behoben.

## Umsetzungsplan

Nur noch Ausbau: QR-Format für [Funktion 22](22-freunde-per-qr-code.md)
ergänzen; beim ersten Scan die
[Hintergrundgeschichte](21-hintergrundgeschichten.md) anbieten.

## Offene Punkte / Ideen

- Etikett-Erkennung per Foto, wenn kein Barcode vorhanden ist
- Barcodes je Bier in eine eigene Tabelle statt kommagetrennt
