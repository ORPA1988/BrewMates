/// Plattform-Weiche für die Drift-Verbindung: Android/Desktop/Tests nutzen
/// die native SQLite-Datei (byte-identisch zum bisherigen Verhalten), das
/// Web `WasmDatabase` (sqlite3.wasm + drift_worker.js aus `web/`).
library;

export 'unsupported.dart'
    if (dart.library.ffi) 'native.dart'
    if (dart.library.js_interop) 'web.dart';
