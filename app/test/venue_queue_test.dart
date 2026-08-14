import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/venue_queue.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<int> enqueueUpdate(String venueId, Map<String, dynamic> patch) =>
      db.enqueueVenueEdit(
        venueId: venueId,
        payloadJson: jsonEncode(patch),
        createdAt: DateTime.utc(2026, 8, 14, 10),
      );

  test('Replay überträgt FIFO und leert die Queue bei Erfolg', () async {
    await enqueueUpdate('v1', {'name': 'Erster'});
    await enqueueUpdate('v2', {'name': 'Zweiter'});

    final order = <String>[];
    final replayed = await replayVenueQueue(
      db,
      create: (_) async => (null, 'unerwartet'),
      update: (id, patch) async {
        order.add(id);
        return null;
      },
    );

    expect(replayed, 2);
    expect(order, ['v1', 'v2']);
    expect(await db.pendingVenueEdits(), isEmpty);
  });

  test('Verbindungsfehler bricht ab – der Rest bleibt liegen', () async {
    await enqueueUpdate('v1', {'name': 'Geht durch'});
    await enqueueUpdate('v2', {'name': 'Scheitert am Netz'});
    await enqueueUpdate('v3', {'name': 'Bleibt liegen'});

    var calls = 0;
    final replayed = await replayVenueQueue(
      db,
      create: (_) async => (null, 'unerwartet'),
      update: (id, patch) async {
        calls++;
        return id == 'v2' ? 'Keine Verbindung – bitte später.' : null;
      },
    );

    expect(replayed, 1);
    expect(calls, 2); // v3 wird gar nicht erst versucht
    final rest = await db.pendingVenueEdits();
    expect(rest.map((e) => e.venueId), ['v2', 'v3']);
  });

  test('Fachlicher Fehler verwirft den Eintrag statt ewig zu blockieren',
      () async {
    await enqueueUpdate('v1', {'name': 'Duplikat'});
    await enqueueUpdate('v2', {'name': 'Geht durch'});

    final replayed = await replayVenueQueue(
      db,
      create: (_) async => (null, 'unerwartet'),
      update: (id, patch) async =>
          id == 'v1' ? 'Dieses Gasthaus gibt es in dem Ort schon.' : null,
    );

    expect(replayed, 1);
    expect(await db.pendingVenueEdits(), isEmpty);
  });

  test('Neuanlage: Pseudo-ID wird im Cache und in Check-ins ersetzt',
      () async {
    const localId = 'local-abc';
    await db.upsertVenues([
      const VenuesCompanion(
        id: Value(localId),
        name: Value('Neues Wirtshaus'),
        category: Value('gasthaus'),
      ),
    ]);
    // Check-in + Session, die schon auf die Pseudo-Zeile zeigen.
    await db.into(db.profiles).insert(ProfilesCompanion.insert(
        id: 'p-test', username: 'tester', displayName: 'Tester'));
    await db.into(db.breweries).insert(BreweriesCompanion.insert(
        id: 'b1', name: 'Brauerei', country: 'AT', city: 'Wien'));
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'beer1', breweryId: 'b1', name: 'Testbier', style: 'Lager'));
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'c1',
          profileId: 'p-test',
          beerId: 'beer1',
          venueId: const Value(localId),
          createdAt: DateTime.utc(2026, 8, 14, 9),
        ));

    await db.enqueueVenueEdit(
      payloadJson: jsonEncode({
        'name': 'Neues Wirtshaus',
        'category': 'gasthaus',
        venueQueueLocalIdKey: localId,
      }),
      createdAt: DateTime.utc(2026, 8, 14, 10),
    );

    Map<String, dynamic>? received;
    final replayed = await replayVenueQueue(
      db,
      create: (payload) async {
        received = payload;
        return ('real-uuid', null);
      },
      update: (_, __) async => 'unerwartet',
    );

    expect(replayed, 1);
    // Der interne Schlüssel darf nicht an den Server gehen.
    expect(received, isNotNull);
    expect(received!.containsKey(venueQueueLocalIdKey), isFalse);

    final venues = await db.select(db.venues).get();
    expect(venues.single.id, 'real-uuid');
    final checkin = await db.select(db.checkins).getSingle();
    expect(checkin.venueId, 'real-uuid');
    expect(await db.pendingVenueEdits(), isEmpty);
  });

  test('Neuanlage mit fachlichem Fehler räumt die Pseudo-Zeile weg',
      () async {
    const localId = 'local-dup';
    await db.upsertVenues([
      const VenuesCompanion(
        id: Value(localId),
        name: Value('Doppelt'),
        category: Value('gasthaus'),
      ),
    ]);
    await db.enqueueVenueEdit(
      payloadJson: jsonEncode({
        'name': 'Doppelt',
        venueQueueLocalIdKey: localId,
      }),
      createdAt: DateTime.utc(2026, 8, 14, 10),
    );

    final replayed = await replayVenueQueue(
      db,
      create: (_) async => (null, 'Dieses Gasthaus gibt es in dem Ort schon.'),
      update: (_, __) async => 'unerwartet',
    );

    expect(replayed, 0);
    expect(await db.select(db.venues).get(), isEmpty);
    expect(await db.pendingVenueEdits(), isEmpty);
  });

  test('Kaputter Payload wird verworfen', () async {
    await db.enqueueVenueEdit(
      payloadJson: 'kein json',
      createdAt: DateTime.utc(2026, 8, 14, 10),
    );
    final replayed = await replayVenueQueue(
      db,
      create: (_) async => (null, 'unerwartet'),
      update: (_, __) async => 'unerwartet',
    );
    expect(replayed, 0);
    expect(await db.pendingVenueEdits(), isEmpty);
  });
}
