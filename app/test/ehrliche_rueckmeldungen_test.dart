import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';

import 'fake_online_service.dart';

/// Kein Erfolg, der nicht stattfand.
///
/// Bis 2026-09-02 setzten Beacon-Start, „Bin dabei", Prost und Check-in
/// ihren Server-Aufruf `unawaited` ab und die Oberflaeche meldete immer
/// Erfolg. Offline sass der Mensch mit gutem Gewissen im Wirtshaus und war
/// fuer niemanden sichtbar. Diese Tests halten fest, dass jede dieser
/// Aktionen jetzt sagt, ob der Server sie hat.
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

  group('Beacon-Start', () {
    test('meldet synced=true, wenn der Server ihn hat', () async {
      final c = container();
      addTearDown(c.dispose);
      final r = await c.read(actionsProvider).startSession(
          visibility: SessionVisibility.friends,
          autoEnd: const Duration(hours: 2));
      expect(r.synced, isTrue);
      expect(online.aufrufe.any((a) => a.startsWith('upsertSession')), isTrue);
      await db.close();
    });

    test('meldet synced=false, wenn der Server ablehnt — lokal läuft er',
        () async {
      online.schlaegtFehl = true;
      final c = container();
      addTearDown(c.dispose);
      final r = await c.read(actionsProvider).startSession(
          visibility: SessionVisibility.friends,
          autoEnd: const Duration(hours: 2));
      expect(r.synced, isFalse,
          reason: 'Genau das wurde vorher verschwiegen.');
      final me = await db.getMe();
      expect(await db.getMyActiveSession(me.id, DateTime.now()), isNotNull,
          reason: 'Lokal darf der Beacon trotzdem laufen — offline first.');
      await db.close();
    });

    test('Erneut versuchen schickt den laufenden Beacon nach', () async {
      online.schlaegtFehl = true;
      final c = container();
      addTearDown(c.dispose);
      await c.read(actionsProvider).startSession(
          visibility: SessionVisibility.friends,
          autoEnd: const Duration(hours: 2));
      online.schlaegtFehl = false;
      expect(await c.read(actionsProvider).resyncMySession(), isTrue);
      await db.close();
    });
  });

  group('Prost und Bin dabei auf fremde Sessions', () {
    test('Prost meldet den Fehlschlag', () async {
      online.schlaegtFehl = true;
      final c = container();
      addTearDown(c.dispose);
      expect(await c.read(actionsProvider).toastSession('remote-s1'), isFalse);
      await db.close();
    });

    test('Bin dabei meldet den Fehlschlag', () async {
      online.schlaegtFehl = true;
      final c = container();
      addTearDown(c.dispose);
      final r = await c.read(actionsProvider).joinSession('remote-s1');
      expect(r.synced, isFalse);
      await db.close();
    });
  });

  group('Toast auf Feed-Eintrag', () {
    test('Server lehnt ab → nichts wird lokal gespiegelt', () async {
      online.schlaegtFehl = true;
      final c = container();
      addTearDown(c.dispose);
      final r = await c
          .read(actionsProvider)
          .toggleServerToast('remote-c1', 'c1', on: true);
      expect(r, isNull, reason: 'null heisst: nicht gesendet.');
      expect(online.aufrufe, contains('setToastRemote:c1:true'));
      await db.close();
    });
  });

  group('Check-in', () {
    test('sagt, ob er beim Server angekommen ist', () async {
      final c = container();
      addTearDown(c.dispose);
      final beers = await db.select(db.beers).get();
      final ok = await c
          .read(actionsProvider)
          .createCheckin(beerId: beers.first.id);
      expect(ok.synced, isTrue);
      online.schlaegtFehl = true;
      final nicht = await c
          .read(actionsProvider)
          .createCheckin(beerId: beers.first.id);
      expect(nicht.synced, isFalse);
      await db.close();
    });
  });

  group('Profil', () {
    test('Aenderung geht auch zum Server', () async {
      final c = container();
      addTearDown(c.dispose);
      final ok = await c
          .read(actionsProvider)
          .updateProfile(displayName: 'Anna', avatarEmoji: '🍺');
      expect(ok, isTrue);
      expect(online.aufrufe, contains('updateMyProfile:Anna:🍺'));
      await db.close();
    });
  });
}
