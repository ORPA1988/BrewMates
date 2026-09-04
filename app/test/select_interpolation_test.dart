// Wächter über Dateien im Repo: liest sie mit `dart:io`. Ein Browser
// hat kein Dateisystem, und geprüft wird hier ohnehin das Repo und
// nicht die App. Siehe docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Waechter gegen einen Fehler, der vom 2026-08-15 bis 2026-09-02 jede
/// eingehende Freundschaftsanfrage unsichtbar machte.
///
/// `'…($OnlineApi.profileCols)'` interpoliert in Dart den **Klassennamen**
/// und haengt `.profileCols` als Text an — der Server bekam woertlich
/// `OnlineApi.profileCols` als Spaltenliste, antwortete 400, und der
/// Client schluckte den Fehler. Richtig ist `${OnlineApi.profileCols}`.
///
/// Der Analyzer meldet das nicht: `$OnlineApi` ist gueltiges Dart. Deshalb
/// prueft dieser Test die Quelltexte selbst, wie der Architektur-Test.
void main() {
  test('Kein Select-String interpoliert eine Klasse statt ihres Feldes', () {
    final treffer = <String>[];
    // Nur ein einzelnes `$` (Drift-Generat nutzt `$$Klasse` als Namen) und
    // nur innerhalb einer Zeichenkette — davor muss ein Anfuehrungszeichen
    // stehen. Generierte Dateien sind ausgenommen.
    final muster = RegExp(r'''['"][^'"]*(?<!\$)\$[A-Z][A-Za-z0-9_]*\.[a-zA-Z_]''');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
        continue;
      }
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        if (muster.hasMatch(zeilen[i])) {
          treffer.add('${f.path}:${i + 1}: ${zeilen[i].trim()}');
        }
      }
    }
    expect(treffer, isEmpty,
        reason: 'Interpolation `\$Klasse.feld` — gemeint war sicher '
            '`\${Klasse.feld}`:\n${treffer.join('\n')}');
  });
}
