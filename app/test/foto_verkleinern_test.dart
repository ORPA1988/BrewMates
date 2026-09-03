import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:brewmates/core/foto_verkleinern.dart';

/// Fotos vor dem Hochladen auf 500 KB bringen.
///
/// **Warum das überhaupt eine Rechnung braucht:** `image_picker` nimmt
/// `maxWidth` und `imageQuality` entgegen — als Bitte, nicht als Zusage.
/// Auf Android hängt die Umsetzung an der Kamera-App, im Browser gilt sie
/// teilweise gar nicht. Und selbst wo sie greift, ist ein 1280er JPEG bei
/// Qualität 80 je nach Motiv 200 KB oder 900 KB. Wer eine Grenze zusagen
/// will, muss sie nachrechnen — und genau das prüfen diese Tests, mit
/// absichtlich schwer komprimierbaren Bildern.
void main() {
  /// Rauschen: das Gegenteil einer glatten Fläche und damit der Fall, an
  /// dem eine zu optimistische Annahme über JPEG-Größen scheitert.
  Uint8List rauschen(int breite, int hoehe, {int quality = 100}) {
    final zufall = Random(42);
    final bild = img.Image(width: breite, height: hoehe);
    for (var y = 0; y < hoehe; y++) {
      for (var x = 0; x < breite; x++) {
        bild.setPixelRgb(
            x, y, zufall.nextInt(256), zufall.nextInt(256), zufall.nextInt(256));
      }
    }
    return Uint8List.fromList(img.encodeJpg(bild, quality: quality));
  }

  test('ein großes, detailreiches Foto passt danach ins Budget', () {
    final gross = rauschen(1600, 1200);
    expect(gross.length, greaterThan(fotoMaxBytes),
        reason: 'Sonst prüft der Test nichts.');

    final klein = verkleinereFoto(gross);

    expect(klein.length, lessThanOrEqualTo(fotoMaxBytes));
    expect(passtInsBudget(klein), isTrue);
  });

  test('die längste Kante wird begrenzt, das Seitenverhältnis bleibt', () {
    // Budget absichtlich groß: Hier soll allein die Kantenregel wirken,
    // nicht die Größenrechnung. (Mit dem echten Budget und Rauschen
    // greift zusätzlich das Halbieren — das prüft der letzte Test.)
    const reichlich = 50 * 1024 * 1024;

    final quer = verkleinereFoto(rauschen(1600, 800), maxBytes: reichlich);
    final querBild = img.decodeImage(quer)!;
    expect(querBild.width, fotoMaxKante);
    expect(querBild.height, 640, reason: '1600×800 → 1280×640');

    final hoch = verkleinereFoto(rauschen(800, 1600), maxBytes: reichlich);
    final hochBild = img.decodeImage(hoch)!;
    expect(hochBild.height, fotoMaxKante);
    expect(hochBild.width, 640);
  });

  test('ein kleines Bild wird nicht vergrößert und nicht angefasst', () {
    // Neu zu kodieren würde nur Qualität kosten, ohne etwas zu sparen.
    final klein = rauschen(400, 300, quality: 60);
    expect(klein.length, lessThan(fotoMaxBytes));

    final ergebnis = verkleinereFoto(klein);

    expect(ergebnis, same(klein),
        reason: 'Unverändert durchgereicht, nicht neu kodiert.');
  });

  test('ein PNG unter der Grenze wird trotzdem zu JPEG', () {
    // PNG-Fotos sind um ein Vielfaches größer als nötig; hier lohnt das
    // Umkodieren auch dann, wenn die Datei schon klein genug ist.
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 50, height: 50)));
    final ergebnis = verkleinereFoto(png);
    expect(ergebnis[0], 0xFF, reason: 'JPEG beginnt mit FF D8 FF.');
    expect(ergebnis[1], 0xD8);
  });

  test('was sich nicht entschlüsseln lässt, kommt unverändert zurück', () {
    // Ein verlorenes Foto wäre schlimmer als ein großes. Der Aufrufer
    // kann `passtInsBudget` fragen.
    final kaputt = Uint8List.fromList(List.filled(1024, 7));
    expect(verkleinereFoto(kaputt), same(kaputt));
  });

  test('ein enges Budget wird auch bei Rauschen eingehalten', () {
    // 50 KB ist absichtlich hart: Hier muss das Verfahren mehrfach
    // halbieren. Genau hier gab die erste Fassung 74 KB zurück — sie
    // hatte eine feste Rundenzahl und eine Untergrenze von 320 px, und
    // die Zusage galt dann nicht mehr.
    final ergebnis = verkleinereFoto(rauschen(1200, 1200), maxBytes: 50 * 1024);
    expect(ergebnis.length, lessThanOrEqualTo(50 * 1024));
  });
}
