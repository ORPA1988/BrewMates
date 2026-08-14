import 'package:drift/wasm.dart';

/// Quelle für `web/drift_worker.js` — wird SELBST kompiliert, damit der
/// Worker exakt dieselbe sqlite3-Dart-Version nutzt wie die App
/// (pubspec.lock). Das vorkompilierte Release-Asset von drift führte zu
/// `LinkError: Import "dart" "localtime"`, weil es gegen ein älteres
/// sqlite3 gebaut war als unser sqlite3.wasm (2.9.4).
///
/// Neu bauen (aus app/):
///   dart compile js -O4 -o web/drift_worker.js tool/drift_worker.dart
void main() {
  WasmDatabase.workerMainForOpen();
}
