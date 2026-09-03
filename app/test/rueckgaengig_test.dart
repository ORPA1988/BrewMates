import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/models.dart';
import 'package:brewmates/data/providers.dart';

import 'fake_online_service.dart';

/// „Rückgängig statt Rückfrage" (Roadmap-Punkt, Issue #65).
///
/// Drei Aktionen, die bisher endgültig waren, und **drei verschiedene
/// Mechaniken** — weil die Aktionen verschieden sind:
///
/// - **Beacon beenden**: sofort beenden, danach wiederbeleben. Ein
///   laufender Beacon zeigt Freunden den Aufenthaltsort; wer „Beenden"
///   tippt, will in dieser Sekunde unsichtbar sein, nicht in fünf.
/// - **Anfrage ablehnen**: nicht rückgängig, sondern aufgeschoben. Das
///   Löschen einer `friendships`-Zeile kann nur der Anfragende
///   zurücknehmen — ein „Rückgängig", das den Server um etwas bittet, was
///   er ablehnen muss, wäre ein Versprechen ohne Deckung.
/// - **Wunschliste**: ein reiner Umschalter, dort ist „Rückgängig"
///   wörtlich derselbe Aufruf noch einmal (im Bildschirm selbst, kein
///   Zustand zum Prüfen).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      onlineServiceProvider.overrideWith((ref) async => online),
      // Ohne angemeldeten Nutzer bleibt `friendRequestsProvider` ewig im
      // Ladezustand — der echte Strom hängt an einem Client, den es im
      // Test nicht gibt.
      onlineUserProvider.overrideWith((ref) => Stream.value(User(
            id: '11111111-1111-1111-1111-111111111111',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime(2026).toIso8601String(),
          ))),
    ]);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  // --------------------------------------------------------------------
  group('Beacon beenden', () {
    Future<Session> starteBeacon() async {
      await container.read(actionsProvider).startSession(
            venueName: 'Augustiner',
            visibility: SessionVisibility.friends,
            autoEnd: const Duration(hours: 3),
          );
      final me = await db.getMe();
      return (await db.getMyActiveSession(me.id, DateTime.now()))!;
    }

    test('holt den Beacon lokal und am Server zurück', () async {
      final vorher = await starteBeacon();
      final beendet = await container.read(actionsProvider).endMySession();
      final me = await db.getMe();
      expect(await db.getMyActiveSession(me.id, DateTime.now()), isNull);

      online.aufrufe.clear();
      final wieder = await container
          .read(actionsProvider)
          .undoEndMySession(beendet!.beendet);

      expect(wieder, isTrue);
      expect(online.aufrufe, contains('upsertSession:${vorher.id}'),
          reason: 'Ohne den Server sieht ihn kein Freund wieder.');
      final aktiv = await db.getMyActiveSession(me.id, DateTime.now());
      expect(aktiv?.id, vorher.id, reason: 'Dieselbe Runde, nicht eine neue.');
      expect(aktiv?.endedAt, isNull);
    });

    test('verlängert dabei nichts', () async {
      // Sonst wäre „Beenden, dann Rückgängig" ein Trick, um die
      // Laufzeitgrenze aus Migration 0021 zu umgehen.
      final vorher = await starteBeacon();
      final beendet = await container.read(actionsProvider).endMySession();
      await container
          .read(actionsProvider)
          .undoEndMySession(beendet!.beendet);

      final me = await db.getMe();
      final aktiv = await db.getMyActiveSession(me.id, DateTime.now());
      expect(aktiv!.expiresAt, vorher.expiresAt);
    });

    test('ein längst abgelaufener Beacon kommt nicht zurück', () async {
      await starteBeacon();
      final beendet = await container.read(actionsProvider).endMySession();
      online.aufrufe.clear();

      final wieder = await container.read(actionsProvider).undoEndMySession(
            beendet!.beendet.copyWith(
              expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
            ),
          );

      expect(wieder, isNull, reason: 'Ehrlich statt scheinbar wiederbelebt.');
      expect(online.aufrufe, isEmpty);
      final me = await db.getMe();
      expect(await db.getMyActiveSession(me.id, DateTime.now()), isNull);
    });

    test('meldet ehrlich, wenn der Server die Wiederbelebung nicht nimmt',
        () async {
      await starteBeacon();
      final beendet = await container.read(actionsProvider).endMySession();
      online.schlaegtFehl = true;

      expect(
        await container.read(actionsProvider).undoEndMySession(beendet!.beendet),
        isFalse,
      );
    });
  });

  // --------------------------------------------------------------------
  group('Anfrage ablehnen', () {
    const kurz = Duration(milliseconds: 40);

    FriendRequest anfrage(String id) => FriendRequest(
          friendshipId: id,
          from: RemoteProfile(
            id: 'p-$id',
            username: 'anna',
            displayName: 'Anna',
            avatarEmoji: '🍺',
          ),
        );

    setUp(() {
      online.anfragen = [anfrage('fs-1'), anfrage('fs-2')];
    });

    Future<void> ladeAnfragen() async {
      // Ohne Zuhörer bleibt der Provider im Ladezustand hängen — dieselbe
      // Zeile steht aus demselben Grund in `push_registrierung_test`.
      container.listen(friendRequestsProvider, (_, __) {});
      await container.read(friendRequestsProvider.future);
    }

    test('die Anfrage verschwindet sofort, der Server hört erst später',
        () async {
      await ladeAnfragen();
      expect(container.read(offeneAnfragenProvider), hasLength(2));

      final laeuft = container
          .read(abgelehnteAnfragenProvider.notifier)
          .ablehnen('fs-1', frist: kurz);

      // Noch in der Frist: aus der Liste raus, aber nichts gelöscht.
      expect(container.read(offeneAnfragenProvider).map((a) => a.friendshipId),
          ['fs-2']);
      expect(online.aufrufe.where((a) => a.startsWith('respondRequest')),
          isEmpty);

      expect(await laeuft, isTrue);
      expect(online.aufrufe, contains('respondRequest:fs-1:false'));
    });

    test('„Rückgängig" verhindert den Aufruf, statt ihn zurückzunehmen',
        () async {
      await ladeAnfragen();
      final laeuft = container
          .read(abgelehnteAnfragenProvider.notifier)
          .ablehnen('fs-1', frist: kurz);

      container
          .read(abgelehnteAnfragenProvider.notifier)
          .zuruecknehmen('fs-1');

      expect(await laeuft, isNull, reason: 'null heißt „ist nicht passiert".');
      expect(online.aufrufe.where((a) => a.startsWith('respondRequest')),
          isEmpty,
          reason: 'Das ist der ganze Punkt: kein Aufruf, kein Schaden.');
      expect(container.read(offeneAnfragenProvider), hasLength(2),
          reason: 'Die Anfrage ist wieder da.');
    });

    test('scheitert der Server, kommt die Anfrage sichtbar zurück', () async {
      await ladeAnfragen();
      online.schlaegtFehl = true;

      expect(
        await container
            .read(abgelehnteAnfragenProvider.notifier)
            .ablehnen('fs-1', frist: kurz),
        isFalse,
      );
      expect(container.read(offeneAnfragenProvider), hasLength(2),
          reason: 'Wer glaubt, abgelehnt zu haben, rechnet nicht mehr damit, '
              'gesehen zu werden — also darf die App das nicht behaupten.');
    });

    test('zwei Ablehnungen kommen sich nicht in die Quere', () async {
      await ladeAnfragen();
      final eins = container
          .read(abgelehnteAnfragenProvider.notifier)
          .ablehnen('fs-1', frist: kurz);
      final zwei = container
          .read(abgelehnteAnfragenProvider.notifier)
          .ablehnen('fs-2', frist: kurz);
      container
          .read(abgelehnteAnfragenProvider.notifier)
          .zuruecknehmen('fs-2');

      expect(await eins, isTrue);
      expect(await zwei, isNull);
      expect(online.aufrufe, contains('respondRequest:fs-1:false'));
      expect(online.aufrufe, isNot(contains('respondRequest:fs-2:false')));
    });

    test('der Zähler zeigt dasselbe wie die Liste', () async {
      // Der Grund für `offeneAnfragenProvider`: Fünf Stellen zeigten die
      // Anfragen, jede hätte den Filter einzeln gebraucht — und eine
      // hätte ihn vergessen.
      await ladeAnfragen();
      final laeuft = container
          .read(abgelehnteAnfragenProvider.notifier)
          .ablehnen('fs-1', frist: kurz);
      expect(container.read(offeneAnfragenProvider).length, 1);
      expect(container.read(friendRequestsProvider).valueOrNull, hasLength(2),
          reason: 'Der Server weiß noch von zweien — das ist auch richtig so.');
      await laeuft;
    });
  });
}
