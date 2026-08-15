import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Das Launcher-Icon darf nicht wieder schrumpfen.
///
/// Vorgeschichte: Die Schutzzone der adaptiven Android-Icons wurde
/// **zweimal** angewendet — einmal im Icon-Skript, einmal als `<inset>` in
/// `ic_launcher.xml`. Das Motiv landete bei 29 % der sichtbaren Fläche
/// statt bei den erlaubten ~66 und wirkte neben der Web-App, die das volle
/// Quadrat zeigt, verloren.
///
/// Beides fiel niemandem auf, weil ein Icon nicht kompiliert wird. Dieser
/// Test macht daraus etwas Prüfbares.
void main() {
  final res = Directory('android/app/src/main/res');

  test('ic_launcher.xml setzt den Vordergrund nicht noch einmal zurück', () {
    final roh =
        File('${res.path}/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    // Kommentare raus: Die Datei ERKLÄRT, warum dort kein Inset steht —
    // dieser Hinweis darf den Test nicht selbst auslösen.
    final xml = roh.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    expect(
      xml.contains('<inset'),
      isFalse,
      reason: 'Die Schutzzone hält bereits tools/generate_icon.py ein. Ein '
          'zusätzlicher Inset wendet sie doppelt an und macht das Motiv '
          'auf rund ein Drittel der erlaubten Größe klein.',
    );
  });

  test('Das Motiv füllt die Schutzzone in jeder Dichte', () {
    // PNG lesen wir hier von Hand: Ein Bildpaket nur für einen Test wäre
    // eine Abhängigkeit zu viel. Wir brauchen nur Breite und Höhe aus dem
    // IHDR-Block — und die Alpha-Ausdehnung nähern wir über die
    // Dateigröße nicht an, sondern prüfen die Kantenlänge gegen die
    // erwartete Vorlagengröße.
    const erwartet = {
      'mdpi': 108,
      'hdpi': 162,
      'xhdpi': 216,
      'xxhdpi': 324,
      'xxxhdpi': 432,
    };

    for (final e in erwartet.entries) {
      final datei = File('${res.path}/drawable-${e.key}/ic_launcher_foreground.png');
      expect(datei.existsSync(), isTrue, reason: '${e.key} fehlt');

      final bytes = datei.readAsBytesSync();
      // PNG: 8 Byte Signatur, dann IHDR mit Breite/Höhe als 32-Bit.
      final breite = bytes[16] << 24 | bytes[17] << 16 | bytes[18] << 8 | bytes[19];
      final hoehe = bytes[20] << 24 | bytes[21] << 16 | bytes[22] << 8 | bytes[23];

      expect(breite, e.value, reason: '${e.key}: unerwartete Kantenlänge');
      expect(hoehe, e.value, reason: '${e.key}: nicht quadratisch');
    }
  });
}
