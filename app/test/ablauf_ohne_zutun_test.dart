import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/models.dart';
import 'package:brewmates/data/providers.dart';

import 'fake_online_service.dart';

/// Was abläuft, muss von selbst verschwinden.
///
/// Beides — Bierlaune und der Beacon eines Freundes — hatte dieselbe
/// Bauart und denselben Fehler: Die Zeit wurde **beim Abrufen** geprüft,
/// nicht beim Anzeigen. Abgerufen wird alle fünf Minuten (Bierlaune) bzw.
/// nur, wenn Realtime eine geänderte Zeile schickt (Beacon) — und eine
/// ablaufende Laufzeit ändert keine Zeile.
///
/// Folge: Ein längst beendeter Beacon stand weiter auf der Karte, mit Ort.
/// Das ist die unangenehmste Sorte Fehler in dieser App, weil sie eine
/// Aussage über den Aufenthaltsort eines Menschen macht, die nicht mehr
/// stimmt.
///
/// Der Zeitfilter liegt jetzt in der Anzeige und hängt am 30-Sekunden-Takt
/// (`clockProvider`). Genau das prüfen diese Tests — indem sie die Uhr
/// selbst stellen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;
  late ProviderContainer container;

  /// Die Uhr, die sonst alle 30 Sekunden tickt — hier von Hand gestellt.
  late StreamController<DateTime> uhr;

  final start = DateTime(2026, 9, 3, 20, 0);

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
    uhr = StreamController<DateTime>.broadcast();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      onlineServiceProvider.overrideWith((ref) async => online),
      clockProvider.overrideWith((ref) => uhr.stream),
      onlineUserProvider.overrideWith((ref) => Stream.value(User(
            id: '11111111-1111-1111-1111-111111111111',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime(2026).toIso8601String(),
          ))),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await uhr.close();
    await db.close();
  });

  /// Die Uhr stellen und den Providern Zeit zum Nachziehen geben.
  ///
  /// Die Pause muss lang genug sein, dass ein etwaiger Abruf **fertig**
  /// wird: Sonst landet er erst nach der Messung und sieht aus wie ein
  /// zusätzlicher, den die Uhr ausgelöst hätte.
  Future<void> stelleUhr(DateTime t) async {
    uhr.add(t);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  group('Bierlaune', () {
    setUp(() {
      online.thirstyBis = start.add(const Duration(minutes: 2));
      online.thirstyFreunde = [
        RemoteProfile(
          id: 'p1',
          username: 'anna',
          displayName: 'Anna',
          avatarEmoji: '🍺',
          thirstyUntil: start.add(const Duration(minutes: 2)),
        ),
        RemoteProfile(
          id: 'p2',
          username: 'bert',
          displayName: 'Bert',
          avatarEmoji: '🍺',
          thirstyUntil: start.add(const Duration(hours: 2)),
        ),
      ];
    });

    test('die eigene endet mit der Uhr, nicht mit dem nächsten Abruf',
        () async {
      container.listen(myThirstyUntilProvider, (_, __) {});
      await container.read(myThirstyUntilProvider.future);

      await stelleUhr(start);
      expect(container.read(bierlauneAktivProvider), isTrue);
      final abrufeVorher =
          online.aufrufe.where((a) => a == 'myThirstyUntil').length;

      // Drei Minuten weiter — noch innerhalb desselben Fünf-Minuten-
      // Takts, es wird also NICHT neu abgefragt. Trotzdem muss der Knopf
      // umschlagen: Genau das war vorher nicht der Fall.
      await stelleUhr(start.add(const Duration(minutes: 3)));
      expect(container.read(bierlauneAktivProvider), isFalse,
          reason: 'Der Knopf darf nicht „Bierlaune bis 20:02" zeigen, '
              'wenn es 20:03 ist.');
      expect(online.aufrufe.where((a) => a == 'myThirstyUntil').length,
          abrufeVorher,
          reason: 'Und zwar ohne dafür noch einmal zu fragen — sonst '
              'prüft der Test nur den Abruf, nicht die Uhr.');
    });

    test('abgelaufene Freunde verschwinden aus der Liste', () async {
      container.listen(thirstyFriendsProvider, (_, __) {});
      await _warteAufFreunde();

      await stelleUhr(start);
      expect(container.read(thirstyFriendsProvider).map((f) => f.username),
          ['anna', 'bert']);
      final abrufeVorher =
          online.aufrufe.where((a) => a == 'thirstyFriends').length;

      // Wieder innerhalb desselben Abruf-Takts.
      await stelleUhr(start.add(const Duration(minutes: 3)));
      expect(container.read(thirstyFriendsProvider).map((f) => f.username),
          ['bert'],
          reason: 'Anna ist durch — man macht sich sonst auf den Weg zu '
              'jemandem, der längst zu Hause ist.');
      expect(online.aufrufe.where((a) => a == 'thirstyFriends').length,
          abrufeVorher,
          reason: 'Ohne erneuten Abruf.');
    });
  });

  group('Beacon eines Freundes', () {
    setUp(() {
      online.freundesSessions = [
        RemoteSession(
          id: 's1',
          host: const RemoteProfile(
            id: 'p1',
            username: 'anna',
            displayName: 'Anna',
            avatarEmoji: '🍺',
          ),
          venueName: 'Augustiner',
          startedAt: start,
          expiresAt: start.add(const Duration(minutes: 20)),
          latitude: 48.2,
          longitude: 16.3,
        ),
      ];
    });

    test('verschwindet, wenn die Laufzeit vorbei ist — ohne neues Ereignis',
        () async {
      container.listen(remoteSessionsProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await stelleUhr(start.add(const Duration(minutes: 5)));
      expect(container.read(remoteSessionsProvider), hasLength(1));

      // Realtime schickt nichts mehr — nur die Uhr läuft weiter. Genau
      // das war der Fall, in dem der Beacon stehen blieb.
      await stelleUhr(start.add(const Duration(minutes: 21)));
      expect(container.read(remoteSessionsProvider), isEmpty,
          reason: 'Ein beendeter Beacon darf keinen Ort mehr behaupten.');
    });
  });
}

/// Der Rohwert steckt hinter einem privaten Provider — ein Tick reicht,
/// damit der FutureProvider dahinter auflöst.
Future<void> _warteAufFreunde() =>
    Future<void>.delayed(const Duration(milliseconds: 50));
