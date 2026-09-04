// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/models.dart';
import 'package:brewmates/data/online/remote_mapping.dart';
import 'package:brewmates/data/providers.dart';

import 'fake_online_service.dart';

/// Was eine Runde zeigt.
///
/// **Der Befund dahinter:** `sessionCheckinsProvider` las ausschließlich
/// die lokale Datenbank — und die kennt nur die **eigenen** Check-ins.
/// Selbst in der eigenen Runde liegen die der Mitrundigen ausschließlich
/// am Server. Für fremde Runden gab der Provider sogar unbesehen eine
/// leere Liste zurück.
///
/// Der Gastgeber sah also nur, was er selbst getrunken hatte, und ein
/// Gast gar nichts. Seit 0050 wären die Zeilen sichtbar — sie wurden nur
/// nie geholt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const meineRunde = 'runde-1';
  const fremdeRunde = 'remote-7c9e6679-7425-40de-944b-e07fc1f90ae7';

  /// Eine Server-Zeile, wie sie in der App ankommt — **mit**
  /// `remote-`-Präfix an der ID, das `remoteCheckinToDetails` setzt.
  CheckinDetails detail(String id, String wer, DateTime wann,
          {String bier = 'Fremdes Bier'}) =>
      remoteCheckinToDetails(RemoteCheckin(
        id: id,
        author: RemoteProfile(
          id: wer,
          username: wer,
          displayName: wer,
          avatarEmoji: '🍺',
        ),
        beerName: bier,
        createdAt: wann,
      ));

  /// Dieselbe Zeile, wie sie **lokal** steht: blanke ID, ohne Präfix.
  /// Genau dieser Unterschied ließ die Entdopplung im ersten Wurf
  /// danebengreifen.
  CheckinDetails lokalerCheckin(String id, DateTime wann,
      {String bier = 'Stiegl-Goldbräu'}) {
    final d = detail(id, 'ich', wann, bier: bier);
    return CheckinDetails(
      checkin: d.checkin.copyWith(id: id),
      beer: d.beer,
      brewery: d.brewery,
      author: d.author,
    );
  }

  group('Zusammenführen', () {
    // Die reine Regel, ohne Verdrahtung: Was gehört in die Liste, in
    // welcher Reihenfolge, und welche Fassung gewinnt bei Dubletten?
    test('Beide Quellen, chronologisch', () {
      final liste = rundeVereinen(
        [lokalerCheckin('c-eigen', DateTime(2026, 8, 15, 20))],
        [detail('c-fremd', 'ben', DateTime(2026, 8, 15, 21))],
      );

      expect(liste.map((d) => d.checkin.id).toList(),
          ['c-eigen', 'remote-c-fremd']);
    });

    test('Auch wenn der fremde früher war', () {
      final liste = rundeVereinen(
        [lokalerCheckin('c-eigen', DateTime(2026, 8, 15, 22))],
        [detail('c-fremd', 'ben', DateTime(2026, 8, 15, 21))],
      );

      expect(liste.map((d) => d.checkin.id).toList(),
          ['remote-c-fremd', 'c-eigen']);
    });

    test('Der eigene Check-in erscheint einmal, nicht zweimal', () {
      // Er steht in beiden Quellen: lokal angelegt, hochgeladen und vom
      // Server zurückgeliefert — dort mit `remote-`-Präfix. Genau daran
      // scheiterte die Entdopplung im ersten Wurf.
      final liste = rundeVereinen(
        [lokalerCheckin('c-eigen', DateTime(2026, 8, 15, 20))],
        [
          detail('c-eigen', 'ich', DateTime(2026, 8, 15, 20)),
          detail('c-fremd', 'ben', DateTime(2026, 8, 15, 21)),
        ],
      );

      expect(liste.length, 2, reason: 'nicht drei');
      // Die lokale Fassung gewinnt — sie ist die vollständigere.
      expect(
        liste.firstWhere((d) => stripRemote(d.checkin.id) == 'c-eigen')
            .beer.name,
        'Stiegl-Goldbräu',
      );
    });

    test('Ohne Server bleibt die eigene Sicht', () {
      final liste = rundeVereinen(
        [lokalerCheckin('c-eigen', DateTime(2026, 8, 15, 20))],
        const [],
      );

      expect(liste.map((d) => d.checkin.id).toList(), ['c-eigen']);
    });
  });

  group('Verdrahtung', () {
    late AppDatabase db;
    late FakeOnlineService online;
    late String myId;

    setUp(() async {
      db = AppDatabase.memory();
      await CommunitySync(db).importBundledData();
      myId = (await db.getMe()).id;
      online = FakeOnlineService();
    });

    tearDown(() => db.close());

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

    /// Wartet, bis der Server-Abruf durch ist.
    ///
    /// Der Provider zeigt **absichtlich sofort** die lokalen Check-ins und
    /// ergänzt die vom Server, sobald sie da sind — die Runden-Ansicht
    /// soll nicht auf das Netz warten. Der erste Wert des Stroms ist
    /// deshalb der unvollständige, und darauf zu prüfen wäre ein Test,
    /// der die falsche Sekunde festhält.
    Future<List<CheckinDetails>> vollstaendig(
        ProviderContainer c, String id) async {
      final sub = c.listen(sessionCheckinsProvider(id), (_, __) {});
      addTearDown(sub.close);
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final werte = c.read(sessionCheckinsProvider(id)).valueOrNull;
        if (werte != null &&
            werte.any((d) => d.checkin.id.endsWith('c-fremd'))) {
          return werte;
        }
      }
      return c.read(sessionCheckinsProvider(id)).valueOrNull ?? const [];
    }

    Future<void> eigenerCheckin(String id, DateTime wann) async {
      final bier = (await db.select(db.beers).get()).first;
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: id,
            profileId: myId,
            beerId: bier.id,
            sessionId: const Value(meineRunde),
            createdAt: wann,
          ));
    }

    test('Die eigene Runde zeigt auch die Check-ins der anderen', () async {
      await eigenerCheckin('c-eigen', DateTime(2026, 8, 15, 20));
      online.rundenCheckins = [
        RemoteCheckin(
          id: 'c-fremd',
          author: const RemoteProfile(
              id: 'ben',
              username: 'ben',
              displayName: 'Ben',
              avatarEmoji: '🍺'),
          beerName: 'Fremdes Bier',
          createdAt: DateTime(2026, 8, 15, 21),
        ),
      ];

      final c = container();
      addTearDown(c.dispose);

      final liste = await vollstaendig(c, meineRunde);
      expect(liste.map((d) => d.checkin.id).toList(),
          ['c-eigen', 'remote-c-fremd']);
    });

    test('Eine fremde Runde zeigt überhaupt etwas', () async {
      // Vorher führte `isRemoteId` zu einer leeren Liste, ohne zu fragen.
      online.rundenCheckins = [
        RemoteCheckin(
          id: 'c-fremd',
          author: const RemoteProfile(
              id: 'ben',
              username: 'ben',
              displayName: 'Ben',
              avatarEmoji: '🍺'),
          beerName: 'Fremdes Bier',
          createdAt: DateTime(2026, 8, 15, 21),
        ),
      ];

      final c = container();
      addTearDown(c.dispose);

      final liste = await vollstaendig(c, fremdeRunde);
      expect(liste.map((d) => d.checkin.id).toList(), ['remote-c-fremd']);
      expect(online.aufrufe, contains(
          'sessionCheckins:7c9e6679-7425-40de-944b-e07fc1f90ae7'),
          reason: 'ohne remote-Präfix, so kennt der Server sie');
    });

    test('Ohne Verbindung bleibt die eigene Sicht bestehen', () async {
      await eigenerCheckin('c-eigen', DateTime(2026, 8, 15, 20));

      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => null),
      ]);
      addTearDown(c.dispose);

      final liste =
          await c.read(sessionCheckinsProvider(meineRunde).future);
      expect(liste.map((d) => d.checkin.id).toList(), ['c-eigen'],
          reason: 'der lokale Zweig trägt weiter, wenn der Server fehlt');
    });
  });
}
