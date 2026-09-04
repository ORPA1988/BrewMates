// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';

import 'fake_online_service.dart';

/// Abgleich eigener Sessions zwischen Geraeten.
///
/// Bis 2026-09-02 beendete jedes Geraet beim Start serverseitig alles,
/// was es lokal nicht kannte. Zwei Geraete — Telefon und Browser — haben
/// zwei lokale Datenbanken; das zweite loeschte damit den Beacon des
/// ersten. Der Mensch nannte es „Synchronisation fehlerhaft". Es war eine
/// Loeschung.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
  });

  ProviderContainer container() => ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => online),
        onlineUserProvider.overrideWith((ref) => Stream.value(User(
              id: '11111111-1111-1111-1111-111111111111',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime(2026).toIso8601String(),
            ))),
      ]);

  test('Eine am anderen Geraet gestartete Session wird uebernommen, '
      'nicht beendet', () async {
    online.aktiveSessionIds.add('s-vom-telefon');
    final c = container();
    addTearDown(c.dispose);

    final geaendert = await c.read(sessionReconcileProvider.future);

    expect(geaendert, 1);
    expect(online.aufrufe.where((a) => a.startsWith('endSession')), isEmpty,
        reason: 'Unbekannt heisst nicht „tot" — es kann das andere Geraet sein.');
    final me = await db.getMe();
    final mine = await db.getMyActiveSession(me.id, DateTime.now());
    expect(mine?.id, 's-vom-telefon');
    expect(mine?.venueName, 'Serverwirt');
    await db.close();
  });

  test('Lokal beendet, am Server noch aktiv: wird nachgezogen', () async {
    final me = await db.getMe();
    final now = DateTime.now();
    await db.upsertSession(SessionsCompanion.insert(
      id: 's-zu-ende',
      hostId: me.id,
      visibility: SessionVisibility.friends,
      status: SessionStatus.ended,
      startedAt: now.subtract(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 1)),
    ));
    online.aktiveSessionIds.add('s-zu-ende');
    final c = container();
    addTearDown(c.dispose);

    await c.read(sessionReconcileProvider.future);

    expect(online.aufrufe, contains('endSession:s-zu-ende'));
    await db.close();
  });

  test('Lokal aktiv und am Server aktiv: nichts passiert', () async {
    final me = await db.getMe();
    final now = DateTime.now();
    await db.upsertSession(SessionsCompanion.insert(
      id: 's-laeuft',
      hostId: me.id,
      visibility: SessionVisibility.friends,
      status: SessionStatus.active,
      startedAt: now,
      expiresAt: now.add(const Duration(hours: 2)),
    ));
    online.aktiveSessionIds.add('s-laeuft');
    final c = container();
    addTearDown(c.dispose);

    final geaendert = await c.read(sessionReconcileProvider.future);

    expect(geaendert, 0);
    expect(online.aufrufe.where((a) => a.startsWith('endSession')), isEmpty);
    await db.close();
  });
}
