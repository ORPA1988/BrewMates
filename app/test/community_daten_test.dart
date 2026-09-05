// Wächter über Dateien im Repo: liest sie mit `dart:io`. Ein Browser
// hat kein Dateisystem, und geprüft wird hier ohnehin das Repo und
// nicht die App. Siehe docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prüft die redaktionelle Community-Datenbank auf den echten Dateien.
///
/// Der Anlass: In `beers-at.json` hingen sämtliche EANs des Gösser
/// NaturRadlers am NaturRadler der Starkenberger Brauerei. Wer die 0,33er
/// Gösser scannte, bekam ein Tiroler Bier vorgeschlagen. Solche Fehler
/// sieht man beim Lesen der Datei nicht — sie fallen erst beim Scannen auf,
/// also beim Nutzer.
///
/// Deshalb hier die Regeln, die eine EAN-Zuordnung tragfähig machen:
///
/// * Eine EAN bezeichnet **eine** Handelseinheit. Zwei Biere, die sich
///   denselben Code teilen, können nicht beide recht haben — und die
///   Scanner-Abfrage ist global über alle Regionen.
/// * Eine EAN ist eine GTIN-8 oder GTIN-13 mit gültiger Prüfziffer. Ein
///   Code, der daran scheitert, ist ein Hauscode aus irgendeinem Regal und
///   gehört nicht in eine überregionale Datenbank. (Der Server erzwingt in
///   `beer_barcodes` ohnehin 8 oder 13 Ziffern.)
/// * Eine Gebindegröße hängt am Code, nicht am Bier — also darf keine
///   dastehen, zu der die Liste den Code gar nicht kennt.
/// * IDs sind über alle Regionen eindeutig, sonst überschreibt der Import
///   den einen Eintrag mit dem anderen.
void main() {
  const bierDateien = [
    'assets/data/beers-at.json',
    'assets/data/beers-by.json',
    'assets/data/beers-de.json',
    'assets/data/beers-ch.json',
  ];
  const brauereiDateien = [
    'assets/data/breweries-at.json',
    'assets/data/breweries-by.json',
    'assets/data/breweries-de.json',
    'assets/data/breweries-ch.json',
  ];

  late List<Map<String, dynamic>> biere;
  late Set<String> brauereien;

  setUpAll(() async {
    biere = [];
    for (final datei in bierDateien) {
      final roh = json.decode(await _lies(datei)) as Map<String, dynamic>;
      biere.addAll((roh['beers'] as List).cast<Map<String, dynamic>>());
    }
    brauereien = {};
    for (final datei in brauereiDateien) {
      final roh = json.decode(await _lies(datei)) as Map<String, dynamic>;
      brauereien.addAll(
          (roh['breweries'] as List).map((b) => b['id'] as String));
    }
  });

  test('Bier-IDs sind über alle Regionen eindeutig', () {
    final gesehen = <String>{};
    final doppelt = <String>[];
    for (final b in biere) {
      if (!gesehen.add(b['id'] as String)) doppelt.add(b['id'] as String);
    }
    expect(doppelt, isEmpty, reason: 'Doppelte Bier-IDs: $doppelt');
  });

  test('Jedes Bier zeigt auf eine Brauerei, die es gibt', () {
    final verwaist = [
      for (final b in biere)
        if (!brauereien.contains(b['brewery_id'])) '${b['id']} → ${b['brewery_id']}'
    ];
    expect(verwaist, isEmpty, reason: 'Biere ohne Brauerei: $verwaist');
  });

  test('Keine EAN gehört zu zwei Bieren', () {
    final zuordnung = <String, List<String>>{};
    for (final b in biere) {
      for (final ean in (b['barcodes'] as List?)?.cast<String>() ?? const []) {
        zuordnung.putIfAbsent(ean, () => []).add(b['id'] as String);
      }
    }
    final mehrfach = [
      for (final e in zuordnung.entries)
        if (e.value.length > 1) '${e.key}: ${e.value.join(", ")}'
    ];
    expect(mehrfach, isEmpty, reason: 'Mehrfach vergebene EANs: $mehrfach');
  });

  test('Jede EAN ist eine gültige GTIN-8 oder GTIN-13', () {
    final ungueltig = <String>[];
    for (final b in biere) {
      for (final ean in (b['barcodes'] as List?)?.cast<String>() ?? const []) {
        if (!_gtinGueltig(ean)) ungueltig.add('${b['id']} → $ean');
      }
    }
    expect(ungueltig, isEmpty, reason: 'Keine gültigen GTINs: $ungueltig');
  });

  test('Gebindegrößen hängen an einer EAN, die das Bier auch führt', () {
    final verwaist = <String>[];
    final unplausibel = <String>[];
    for (final b in biere) {
      final codes = (b['barcodes'] as List?)?.cast<String>() ?? const [];
      final volumen =
          (b['barcode_volumes'] as Map<String, dynamic>?) ?? const {};
      volumen.forEach((ean, ml) {
        if (!codes.contains(ean)) verwaist.add('${b['id']} → $ean');
        final wert = (ml as num).toInt();
        // Obergrenze 1000 ml, weil hier die **Trinkmenge** steht und
        // nicht die Verkaufseinheit. Eine EAN darf ein Sixpack
        // bezeichnen — Open Food Facts führt zu 9003400391632 „3000 ml,
        // 6er-Tragerl". Wer das scannt, trinkt eine Flasche daraus,
        // keine drei Liter; eingetragen wird deshalb 3000/6 = 500. Der
        // größte Wert, den die App überhaupt anbietet, ist 1 l
        // (`volumeChoicesMl`, Growler).
        if (wert < 100 || wert > 1000) unplausibel.add('${b['id']} → $ean = $ml');
      });
    }
    expect(verwaist, isEmpty, reason: 'Größe ohne passenden Code: $verwaist');
    expect(unplausibel, isEmpty, reason: 'Unplausible Größe: $unplausibel');
  });

  test('Alkoholfrei und Alkoholgehalt widersprechen sich nicht', () {
    final widerspruch = <String>[];
    for (final b in biere) {
      final abv = (b['abv'] as num?)?.toDouble();
      if (abv == null) continue;
      final frei = b['is_alcohol_free'] as bool? ?? false;
      if (frei != (abv <= 0.5)) widerspruch.add('${b['id']}: $abv / $frei');
    }
    expect(widerspruch, isEmpty, reason: 'Widerspruch: $widerspruch');
  });
}

/// Prüfziffer nach GS1 (GTIN-8 und GTIN-13).
bool _gtinGueltig(String code) {
  if (code.length != 8 && code.length != 13) return false;
  if (!RegExp(r'^\d+$').hasMatch(code)) return false;
  final ziffern = code.split('').map(int.parse).toList();
  final pruef = ziffern.removeLast();
  var summe = 0;
  for (var i = 0; i < ziffern.length; i++) {
    // Von rechts gezählt wechseln sich 3 und 1 ab, beginnend mit 3.
    final gewicht = (ziffern.length - 1 - i) % 2 == 0 ? 3 : 1;
    summe += ziffern[i] * gewicht;
  }
  return (10 - summe % 10) % 10 == pruef;
}

Future<String> _lies(String asset) async {
  for (final pfad in [asset, '../$asset']) {
    final datei = File(pfad);
    if (await datei.exists()) return datei.readAsString();
  }
  fail('Asset nicht gefunden: $asset');
}
