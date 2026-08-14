import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

/// Web-Backend: `WasmDatabase` wählt selbst die beste verfügbare
/// Speicher-Implementierung (OPFS → IndexedDB → in-memory). Die beiden
/// Runtime-Dateien liegen versionsgepinnt in `web/` (sqlite3 2.9.4,
/// drift 2.23.1 — bei Paket-Upgrades neu herunterladen!). Relative URIs,
/// damit der `--base-href /BrewMates/` von GitHub Pages greift.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'brewmates',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    if (result.missingFeatures.isNotEmpty) {
      // Funktional ok — nur ggf. langsamer/flüchtiger. Für die Diagnose
      // im Browser-Log sichtbar machen.
      debugPrint('Drift-Web: eingeschränkter Speicher '
          '(${result.chosenImplementation}); fehlende Browser-Features: '
          '${result.missingFeatures}');
    }
    return result.resolvedExecutor;
  });
}

/// Tests laufen auf der VM — im Browser gibt es kein NativeDatabase.memory.
QueryExecutor openInMemory() =>
    throw UnsupportedError('In-Memory-Datenbank gibt es nur in VM-Tests.');
