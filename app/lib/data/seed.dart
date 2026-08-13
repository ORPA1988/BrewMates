import 'package:drift/drift.dart';

import 'db/database.dart';

/// Legt beim ersten Start nur das eigene Profil an.
///
/// Früher wurden hier Demo-Freunde, -Sessions und ein Demo-Bierkatalog
/// eingespielt; seit die Beta mit echten Nutzern und der gebündelten
/// Community-Datenbank (AT + Bayern) läuft, startet die App leer.
/// Bestandsinstallationen räumt die Schema-Migration v5 auf.
///
/// Wird genau einmal in [MigrationStrategy.onCreate] aufgerufen.
Future<void> seedDatabase(AppDatabase db) async {
  await db.into(db.profiles).insert(ProfilesCompanion.insert(
        id: 'me',
        username: 'du',
        displayName: 'Du',
        avatarEmoji: const Value('🍻'),
        isMe: const Value(true),
      ));
}
