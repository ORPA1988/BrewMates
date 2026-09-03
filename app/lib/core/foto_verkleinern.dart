import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Höchstgröße eines Fotos, das die App hochlädt.
///
/// 500 KB sind reichlich für ein Etikett auf einem Telefonbildschirm und
/// wenig genug, dass der Upload im Wirtshaus-WLAN nicht hängt. Der Bucket
/// erlaubt seit 0035 fünf Megabyte — das ist die Obergrenze gegen
/// Missbrauch, kein Ziel.
const fotoMaxBytes = 500 * 1024;

/// Längste Kante nach dem Verkleinern.
///
/// 1280 px reichen für Vollbild auf jedem Telefon. Größer bringt bei
/// einem Etikettfoto nichts, was man sähe — nur Bytes.
const fotoMaxKante = 1280;

/// Verkleinert ein Foto auf höchstens [maxBytes] und gibt JPEG zurück.
///
/// **Warum das nötig ist, obwohl `image_picker` schon `maxWidth` und
/// `imageQuality` kann:** Beides ist eine Bitte, keine Zusage. Auf
/// Android hängt die Umsetzung an der Kamera-App, im Browser gilt sie
/// teilweise gar nicht — und selbst wenn sie greift, ist ein 1280er JPEG
/// bei Qualität 80 je nach Motiv 200 KB oder 900 KB. Wer eine Grenze
/// zusagen will, muss sie nachrechnen.
///
/// Das Verfahren in der Reihenfolge, in der es Qualität kostet:
///
///   1. Kante auf [maxKante] begrenzen — kostet nichts Sichtbares
///   2. JPEG-Qualität schrittweise senken, bis es passt
///   3. erst danach die Kante halbieren und von vorn
///
/// **Wenn sich das Bild nicht entschlüsseln lässt** (unbekanntes Format,
/// beschädigt), kommen die ursprünglichen Bytes unverändert zurück. Die
/// Alternative wäre, das Foto zu verwerfen — und ein verlorenes Foto ist
/// schlimmer als ein großes. Der Aufrufer kann [passtInsBudget] fragen.
///
/// Läuft rein in Dart und damit auf allen Plattformen gleich; wegen der
/// Rechenzeit gehört der Aufruf in einen `compute`-Aufruf.
Uint8List verkleinereFoto(
  Uint8List bytes, {
  int maxBytes = fotoMaxBytes,
  int maxKante = fotoMaxKante,
}) {
  final bild = img.decodeImage(bytes);
  if (bild == null) return bytes;

  // Schon in Ordnung? Dann nichts anfassen — neu zu kodieren würde nur
  // Qualität kosten, ohne ein Byte zu sparen. „In Ordnung" heißt beides:
  // im Budget UND innerhalb der Kante. Nur auf die Größe zu schauen,
  // ließe ein 4000 px breites, gut komprimiertes Bild durch — und das
  // ist zwar klein genug, aber niemand sieht davon je mehr als 1280 px.
  if (_istJpeg(bytes) &&
      bytes.length <= maxBytes &&
      _laengsteKante(bild) <= maxKante) {
    return bytes;
  }

  var stufe = _passendVerkleinert(bild, maxKante);
  var letzterVersuch = Uint8List(0);
  while (true) {
    for (final qualitaet in const [85, 70, 55, 40]) {
      final kodiert = img.encodeJpg(stufe, quality: qualitaet);
      if (kodiert.length <= maxBytes) return kodiert;
      letzterVersuch = kodiert;
    }
    // Alle Qualitätsstufen ausgereizt: Bild halbieren und von vorn. Das
    // trifft nur sehr große, sehr detailreiche Vorlagen — bei 500 KB
    // praktisch nie, bei einem engeren Budget schon.
    //
    // Die Schleife hatte zuerst eine feste Zahl von Runden und eine
    // Untergrenze von 320 px. Beides war zu großzügig: Bei einem Budget
    // von 50 KB und einer verrauschten Vorlage kam sie an der Grenze an
    // und gab trotzdem 74 KB zurück — also eine Zusage, die nicht galt.
    final naechsteKante = (_laengsteKante(stufe) / 2).round();
    // Unter 64 px ist nichts mehr zu erkennen; dann lieber ein etwas zu
    // großes Foto als ein unbrauchbares.
    if (naechsteKante < 64) return letzterVersuch;
    stufe = _passendVerkleinert(stufe, naechsteKante);
  }
}

/// Passt [bytes] in das Budget? Für Meldungen an den Menschen.
bool passtInsBudget(Uint8List bytes, {int maxBytes = fotoMaxBytes}) =>
    bytes.length <= maxBytes;

int _laengsteKante(img.Image bild) =>
    bild.width > bild.height ? bild.width : bild.height;

/// Verkleinert proportional, sodass die längste Kante [kante] nicht
/// überschreitet. Kleinere Bilder werden **nicht** vergrößert.
img.Image _passendVerkleinert(img.Image bild, int kante) {
  if (_laengsteKante(bild) <= kante) return bild;
  return bild.width >= bild.height
      ? img.copyResize(bild, width: kante)
      : img.copyResize(bild, height: kante);
}

/// JPEG beginnt mit FF D8 FF.
bool _istJpeg(Uint8List b) =>
    b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
