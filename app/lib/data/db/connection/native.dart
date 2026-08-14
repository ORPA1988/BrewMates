import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Unverändert zum bisherigen `_openConnection()` in database.dart —
/// gleicher Pfad, gleiche Datei, damit bestehende Android-Installationen
/// ihre Datenbank behalten.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'brewmates.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// In-Memory-Datenbank für Tests (`AppDatabase.memory()`).
QueryExecutor openInMemory() => NativeDatabase.memory();
