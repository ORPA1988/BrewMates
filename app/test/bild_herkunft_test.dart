// Wächter über Dateien im Repo: liest sie mit `dart:io`. Ein Browser
// hat kein Dateisystem, und geprüft wird hier ohnehin das Repo und
// nicht die App. Siehe docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jedes Produktbild muss seine Herkunft mitbringen.
///
/// Seit 2026-08-15 verlinkt die App auch Produktfotos von den
/// Brauerei-Webseiten. Bei Open Food Facts folgt die Zuordnung aus der
/// Lizenz (CC-BY-SA); bei einer Brauerei folgt sie aus **nichts** — außer
/// wir schreiben sie dazu.
///
/// Genau das prüft dieser Test, und zwar auf den echten Daten. Ein Bild
/// ohne Quelle ist kein Schönheitsfehler, sondern der Unterschied
/// zwischen Zitieren und Nehmen.
void main() {
  const dateien = [
    'assets/data/beers-at.json',
    'assets/data/beers-by.json',
    'assets/data/beers-de.json',
    'assets/data/beers-ch.json',
  ];

  test('Kein Bild von einer fremden Seite ohne Quellenangabe', () async {
    final ohneQuelle = <String>[];
    var mitBild = 0;

    for (final datei in dateien) {
      final roh = await _lies(datei);
      final liste = (json.decode(roh) as Map<String, dynamic>)['beers'] as List;
      for (final e in liste) {
        final b = e as Map<String, dynamic>;
        final url = b['image_url'] as String?;
        if (url == null) continue;
        mitBild++;
        if (url.startsWith('https://images.openfoodfacts.org/')) continue;
        final quelle = b['image_source'] as String?;
        if (quelle == null || !quelle.startsWith('https://')) {
          ohneQuelle.add('${b['id']} → $url');
        }
      }
    }

    expect(mitBild, greaterThan(0), reason: 'Testdaten gefunden?');
    expect(ohneQuelle, isEmpty,
        reason: 'Diese Bilder zeigen fremdes Material ohne Herkunft: '
            '${ohneQuelle.take(5)}');
  });

  test('Bilder werden nur verlinkt, nie mitgeliefert', () async {
    // Ein data:-URI wäre eine eingebettete Kopie — damit hätten wir das
    // Bild gespeichert statt verlinkt, und die Lizenzlage änderte sich.
    for (final datei in dateien) {
      final roh = await _lies(datei);
      final liste = (json.decode(roh) as Map<String, dynamic>)['beers'] as List;
      for (final e in liste) {
        final url = (e as Map<String, dynamic>)['image_url'] as String?;
        if (url == null) continue;
        expect(url.startsWith('https://'), isTrue,
            reason: '${e['id']}: nur https-Verweise, keine Einbettung');
      }
    }
  });
}

/// Liest eine Datendatei direkt vom Dateisystem.
///
/// Ueber das Asset-Bundle waere ein Widget-Binding noetig; hier geht es
/// nur um den Inhalt der eingecheckten Dateien.
Future<String> _lies(String pfad) => File(pfad).readAsString();
