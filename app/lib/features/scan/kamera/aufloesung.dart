/// Plattform-Weiche für die Kamera-Auflösung im Browser.
///
/// Nativ ein No-op: Dort stellt mobile_scanner die Kamera selbst ein.
library;

export 'aufloesung_stub.dart' if (dart.library.js_interop) 'aufloesung_web.dart';
