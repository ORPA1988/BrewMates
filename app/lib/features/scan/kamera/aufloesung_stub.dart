/// Android, iOS, Desktop: nichts zu tun.
///
/// `MobileScannerController(cameraResolution: …)` wird dort ausgewertet
/// — nur im Browser nicht (siehe `aufloesung_web.dart`). Gibt deshalb
/// auch nichts zurück: Es gibt nichts zu berichten.
Future<String?> erhoeheKameraAufloesung() async => null;
