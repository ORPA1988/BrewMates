// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/remote_mapping.dart';
import 'package:brewmates/data/providers.dart';

/// Die eigene Session-ID trägt **kein** `remote-`-Präfix.
///
/// Das klingt nach einer Belanglosigkeit und war der Grund für drei
/// Fehler auf einmal: `isRemoteId(eigeneSession.id)` ist immer `false`,
/// weil das Präfix ausschließlich beim Übersetzen FREMDER Sessions
/// vergeben wird. Wer daraus „ist noch nicht hochgeladen" liest, baut
/// eine Bedingung, die immer greift:
///
/// - Verlängern rief den Server nie an und meldete trotzdem Erfolg
/// - Beenden ebenso
/// - die Aufräumroutine hätte den eigenen laufenden Beacon abgeschaltet
///
/// Die eigene ID ist zugleich die Server-ID: `upsertSession` überträgt sie
/// unverändert. Es gibt für Sessions bewusst kein `local-…`-Schema wie bei
/// Gasthäusern. Bricht dieser Test, ist eine dieser beiden Annahmen
/// gekippt — dann müssen die Stellen in `providers.dart` mit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      onlineServiceProvider.overrideWith((ref) async => null),
    ]);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  test('Eigene Session-ID ist eine blanke UUID ohne remote-Präfix', () async {
    await container.read(actionsProvider).startSession(
          venueName: 'Augustiner',
          visibility: SessionVisibility.friends,
          autoEnd: const Duration(hours: 3),
        );

    final me = await db.getMe();
    final session = await db.getMyActiveSession(me.id, DateTime.now());

    expect(session, isNotNull);
    expect(isRemoteId(session!.id), isFalse,
        reason: 'Nur fremde Sessions tragen das Präfix. Wer es hier als '
            '„noch nicht hochgeladen" deutet, baut eine Bedingung, die '
            'immer greift.');
    expect(stripRemote(session.id), session.id,
        reason: 'Die lokale ID ist unverändert die Server-ID.');
  });

  test('Fremde Sessions tragen das Präfix — daher stammt die Verwechslung',
      () {
    expect(isRemoteId('${remotePrefix}abc'), isTrue);
    expect(stripRemote('${remotePrefix}abc'), 'abc');
  });
}
