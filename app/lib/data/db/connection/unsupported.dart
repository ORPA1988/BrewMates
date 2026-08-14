import 'package:drift/drift.dart';

/// Fallback für Plattformen ohne ffi und ohne Web-JS — sollte nie laufen.
QueryExecutor openConnection() =>
    throw UnsupportedError('Keine Drift-Implementierung für diese Plattform.');

QueryExecutor openInMemory() =>
    throw UnsupportedError('Keine Drift-Implementierung für diese Plattform.');
