// CSV-Export (Funktion 20, Punkt 7 · Wunsch #133).
//
// Reine Logik, kein Widget: `rohdatenCsv` und `auswertungCsv` bekommen
// Listen und geben Text zurück. Geprüft wird vor allem, was eine
// Tabelle zerreißt — Semikolon, Anführungszeichen, Zeilenumbruch.

import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/checkin_facts.dart';
import 'package:brewmates/core/serving_style.dart';
import 'package:brewmates/domain/statistics.dart';
import 'package:brewmates/domain/statistics/csv.dart';

CheckinFacts _facts({
  required DateTime at,
  String name = 'Gösser Märzen',
  String? note,
  int? volumeMl,
  ServingStyle? serving,
  double? rating,
  String? sessionId,
}) =>
    CheckinFacts(
      createdAt: at,
      beerId: 'b1',
      beerName: name,
      beerStyle: 'Märzen',
      isAlcoholFree: false,
      breweryId: 'br1',
      breweryName: 'Brauerei Göss',
      breweryCountry: 'AT',
      breweryCity: 'Leoben',
      note: note,
      volumeMl: volumeMl,
      serving: serving,
      rating: rating,
      sessionId: sessionId,
    );

void main() {
  group('Rohdaten', () {
    test('Kopfzeile für Excel, dann die Spaltennamen', () {
      final csv = rohdatenCsv([_facts(at: DateTime(2026, 9, 5, 19, 30))]);
      final zeilen = csv.split('\r\n');

      // Ohne `sep=;` zerlegt Excel in deutscher Ländereinstellung eine
      // Semikolon-Datei nicht.
      expect(zeilen.first, 'sep=;');
      expect(zeilen[1], startsWith('datum;uhrzeit;bier;'));
    });

    test('Datum ISO, Uhrzeit zweistellig', () {
      final csv = rohdatenCsv([_facts(at: DateTime(2026, 9, 5, 9, 5))]);
      expect(csv.split('\r\n')[2], startsWith('2026-09-05;09:05;'));
    });

    test('Älteste zuerst — eine Tabelle liest man durch die Zeit', () {
      final csv = rohdatenCsv([
        _facts(at: DateTime(2026, 9, 5), name: 'Zweites'),
        _facts(at: DateTime(2026, 9, 1), name: 'Erstes'),
      ]);
      final zeilen = csv.split('\r\n');
      expect(zeilen[2], contains('Erstes'));
      expect(zeilen[3], contains('Zweites'));
    });

    test('Ein Semikolon in der Notiz zerreißt die Zeile nicht', () {
      final csv = rohdatenCsv(
          [_facts(at: DateTime(2026, 9, 5), note: 'malzig; süffig')]);
      expect(csv, contains('"malzig; süffig"'));
      // Die Datenzeile hat weiterhin genau so viele Felder wie der Kopf.
      final zeilen = csv.split('\r\n');
      expect(_felder(zeilen[2]).length, _felder(zeilen[1]).length);
    });

    test('Anführungszeichen werden verdoppelt (RFC 4180)', () {
      final csv = rohdatenCsv(
          [_facts(at: DateTime(2026, 9, 5), note: 'sagte "prost"')]);
      expect(csv, contains('"sagte ""prost"""'));
    });

    test('Ein Zeilenumbruch in der Notiz bleibt im Feld', () {
      final csv = rohdatenCsv(
          [_facts(at: DateTime(2026, 9, 5), note: 'erste\nzweite')]);
      expect(csv, contains('"erste\nzweite"'));
    });

    test('Gebinde steht als Wort, Runde als ja/nein', () {
      final csv = rohdatenCsv([
        _facts(
            at: DateTime(2026, 9, 5),
            serving: ServingStyle.draft,
            sessionId: 's1')
      ]);
      expect(csv, contains('vom Fass'));
      expect(csv.split('\r\n')[2], endsWith(';ja;'));
    });

    test('Was fehlt, bleibt leer — nicht 0 und nicht „null"', () {
      final csv = rohdatenCsv([_facts(at: DateTime(2026, 9, 5))]);
      final felder = _felder(csv.split('\r\n')[2]);
      expect(felder, isNot(contains('null')));
      // menge_ml, bewertung und notiz sind hier leer.
      expect(felder.where((f) => f.isEmpty).length, greaterThanOrEqualTo(3));
    });
  });

  group('Auswertung', () {
    test('Eine Zeile je Balken, mit Anteil', () {
      final csv = auswertungCsv('stil', const [
        StatSlice('Märzen', 3),
        StatSlice('Pils', 1),
      ]);
      final zeilen = csv.split('\r\n');
      expect(zeilen.first, 'sep=;');
      expect(zeilen[1], 'Stil;anzahl;anteil_prozent');
      expect(zeilen[2], 'Märzen;3;75.0');
      expect(zeilen[3], 'Pils;1;25.0');
    });

    test('Ohne Balken keine Division durch null', () {
      final csv = auswertungCsv('stil', const []);
      expect(csv.split('\r\n').length, 2);
    });
  });
}

/// Zerlegt eine CSV-Zeile so, wie eine Tabellenkalkulation es täte:
/// Semikolon trennt, außer innerhalb von Anführungszeichen.
List<String> _felder(String zeile) {
  final felder = <String>[];
  final puffer = StringBuffer();
  var inAnfuehrung = false;
  for (var i = 0; i < zeile.length; i++) {
    final c = zeile[i];
    if (c == '"') {
      inAnfuehrung = !inAnfuehrung;
    } else if (c == ';' && !inAnfuehrung) {
      felder.add(puffer.toString());
      puffer.clear();
    } else {
      puffer.write(c);
    }
  }
  felder.add(puffer.toString());
  return felder;
}
