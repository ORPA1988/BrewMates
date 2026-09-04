import 'dart:js_interop';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

/// Die Kamera im Browser um eine höhere Auflösung bitten.
///
/// **Warum es das überhaupt gibt.** `MobileScannerController` nimmt eine
/// `cameraResolution` entgegen — der Web-Teil von `mobile_scanner` liest
/// sie aber **nirgends**. Nachgeprüft in 5.2.3 (unsere Fassung) und in
/// 6.0.11 (die nächste, die mit Flutter 3.24 überhaupt auflösbar wäre):
/// `grep cameraResolution lib/src/web/` findet in beiden **null** Treffer.
/// Der Aufruf von `getUserMedia` setzt dort ausschließlich `facingMode`.
///
/// Ohne Vorgabe liefert der Browser seine Voreinstellung, auf Android-
/// Chrome typischerweise **640×480**. Für einen QR-Code ist das reichlich
/// — deshalb funktionieren der Freundes- und der Crew-Scanner. Ein EAN-13
/// hat aber 95 Module nebeneinander: Füllt der Code die halbe Bildbreite,
/// bleiben knapp drei Pixel je Modul, und davon frisst jede Unschärfe die
/// Hälfte. Der Scanner öffnet dann, sieht ein Bild und erkennt nie etwas
/// — genau das gemeldete Verhalten.
///
/// **Was hier passiert:** Nachdem mobile_scanner den Datenstrom
/// aufgebaut hat, wird derselbe Datenstrom gebeten, in Full HD zu
/// liefern. `applyConstraints` wirkt auf die laufende Spur; zxing
/// berechnet seine Arbeitsfläche bei jedem Bild neu aus
/// `videoWidth`/`videoHeight` und übernimmt die neue Größe dadurch von
/// selbst.
///
/// **`ideal`, nicht `exact`.** Eine Kamera, die kein Full HD kann, soll
/// weiterlaufen und nicht mit `OverconstrainedError` stehenbleiben. Aus
/// demselben Grund ist jeder Fehler hier ein Grund weiterzumachen: Der
/// Scanner arbeitet dann eben mit der Voreinstellung wie bisher.
///
/// Gibt zurück, was die Kamera **tatsächlich** liefert (z. B. „1280×1720")
/// — nicht, was gebeten wurde. Der Bildschirm zeigt das an, und das ist
/// kein Selbstzweck: Bleibt der Scanner stumm, unterscheidet genau diese
/// Zahl „die Bitte ist verpufft" von „auflösend genug und trotzdem
/// nichts" — zwei Befunde mit völlig verschiedenen nächsten Schritten.
Future<String?> erhoeheKameraAufloesung() async {
  try {
    // mobile_scanner hängt sein <video> in einen Platform-View; welchen,
    // ist Interna. Gesucht wird deshalb nach dem Merkmal statt nach der
    // Struktur: ein Video-Element mit einem laufenden Kamerastrom.
    final videos = web.document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      final video = videos.item(i) as web.HTMLVideoElement?;
      // `srcObject` ist als MediaProvider getippt; ein Kamerastrom ist
      // immer ein MediaStream. Passt der Typ wider Erwarten nicht, fängt
      // das der try-Block unten — dann bleibt es bei der Voreinstellung.
      final stream = video?.srcObject as web.MediaStream?;
      if (stream == null) continue;

      final spuren = stream.getVideoTracks().toDart;
      for (final spur in spuren) {
        await spur
            .applyConstraints(web.MediaTrackConstraints(
              width: web.ConstrainULongRange(ideal: 1920),
              height: web.ConstrainULongRange(ideal: 1080),
            ))
            .toDart;
        final s = spur.getSettings();
        debugPrint('Scanner: Kamera um 1920×1080 gebeten, '
            'bekommen ${s.width}×${s.height}');
        return '${s.width}×${s.height}';
      }
    }
  } catch (fehler) {
    // Kein Grund zur Aufregung: Ohne die Bitte läuft der Scanner mit der
    // Voreinstellung weiter — schlechter, aber nicht kaputt.
    debugPrint('Scanner: Auflösung ließ sich nicht anheben ($fehler)');
  }
  return null;
}
