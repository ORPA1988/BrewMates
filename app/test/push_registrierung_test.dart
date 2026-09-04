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
import 'fake_push_service.dart';

/// Push-Registrierung: Das Geraetetoken muss beim Server liegen — sonst
/// gibt es keinen Push, und niemand merkt es, weil die App ja laeuft.
///
/// Drei Dinge, die still schiefgehen koennten: kein Register nach dem
/// Login, kein Register nach einem Token-Wechsel, und ein Token, das nach
/// dem Abmelden stehen bleibt (das Telefon klingelte dann fuer ein Konto,
/// das dort nicht mehr angemeldet ist).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;
  late FakePushService push;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
    push = FakePushService();
  });

  ProviderContainer container({bool angemeldet = true}) => ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineServiceProvider.overrideWith((ref) async => online),
          pushServiceProvider.overrideWith((ref) async => push),
          onlineUserProvider.overrideWith((ref) => Stream.value(angemeldet
              ? User(
                  id: '11111111-1111-1111-1111-111111111111',
                  appMetadata: const {},
                  userMetadata: const {},
                  aud: 'authenticated',
                  createdAt: DateTime(2026).toIso8601String(),
                )
              : null)),
        ],
      );

  Future<void> ruhe() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('Nach der Anmeldung liegt das Token beim Server', () async {
    final c = container();
    addTearDown(c.dispose);
    c.listen(pushRegistrationProvider, (_, __) {});
    await ruhe();
    await ruhe();

    expect(push.aufrufe, contains('requestPermission'));
    expect(online.aufrufe, contains('devices.register:tok-1'));
    expect(c.read(registeredPushTokenProvider), 'tok-1');
    await db.close();
  });

  test('Ein Token-Wechsel wird nachgetragen', () async {
    final c = container();
    addTearDown(c.dispose);
    c.listen(pushRegistrationProvider, (_, __) {});
    await ruhe();
    await ruhe();

    push.tokenWechseln('tok-2');
    await ruhe();

    expect(online.aufrufe, contains('devices.register:tok-2'));
    expect(c.read(registeredPushTokenProvider), 'tok-2');
    await db.close();
  });

  test('Ohne Anmeldung passiert nichts', () async {
    final c = container(angemeldet: false);
    addTearDown(c.dispose);
    c.listen(pushRegistrationProvider, (_, __) {});
    await ruhe();
    await ruhe();

    expect(online.aufrufe.where((a) => a.startsWith('devices.')), isEmpty);
    expect(push.aufrufe, isEmpty);
    await db.close();
  });

  test('Eine Vordergrund-Nachricht entwertet die Listen', () async {
    final c = container();
    addTearDown(c.dispose);
    c.listen(pushRegistrationProvider, (_, __) {});
    c.listen(friendRequestsProvider, (_, __) {});
    await ruhe();
    await ruhe();
    final vorher = online.aufrufe.where((a) => a == 'incomingRequests').length;

    push.nachrichtImVordergrund();
    await ruhe();
    await ruhe();

    final nachher = online.aufrufe.where((a) => a == 'incomingRequests').length;
    expect(nachher, greaterThan(vorher));
    await db.close();
  });
}
