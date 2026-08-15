import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';

/// Feed und Tagebuch laden seitenweise und suchen in der Abfrage.
/// Beides hing vorher an einer Abfrage ohne Obergrenze.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late String myId;
  late List<Beer> allBeers;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    myId = (await db.getMe()).id;
    allBeers = await db.select(db.beers).get();
  });

  tearDown(() => db.close());

  /// Legt [count] Check-ins an, der jüngste zuerst (Index 0 = neuester).
  Future<void> seedCheckins(int count, {String? note}) async {
    for (var i = 0; i < count; i++) {
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: 'c$i',
            profileId: myId,
            beerId: allBeers[i % allBeers.length].id,
            note: Value(note),
            createdAt: DateTime.utc(2026, 8, 15, 12).subtract(
              Duration(minutes: i),
            ),
          ));
    }
  }

  test('Ohne Grenze kommt alles – die Grenze schneidet ab', () async {
    await seedCheckins(50);

    expect((await db.watchFeed().first).length, 50);
    expect((await db.watchFeed(limit: 30).first).length, 30);
  });

  test('Das Fenster liefert immer die neuesten zuerst', () async {
    await seedCheckins(50);

    final page = await db.watchFeed(limit: 10).first;
    expect(page.first.checkin.id, 'c0');
    // c0 ist der jüngste, danach absteigend.
    expect(page.map((d) => d.checkin.id).toList(),
        ['c0', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9']);
  });

  test('Größeres Fenster holt die nächste Seite dazu', () async {
    await seedCheckins(50);

    final first = await db.watchFeed(limit: 30).first;
    final second = await db.watchFeed(limit: 60).first;

    expect(first, hasLength(30));
    expect(second, hasLength(50));
    // Die erste Seite bleibt vorne stehen – kein Springen beim Nachladen.
    expect(second.take(30).map((d) => d.checkin.id).toList(),
        first.map((d) => d.checkin.id).toList());
  });

  test('Suche läuft in der Abfrage, nicht hinter dem Fenster', () async {
    // Ein gesuchter Eintrag liegt ganz hinten – ein Filter über die
    // geladene Seite würde ihn nie finden.
    await seedCheckins(50);
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'gesucht',
          profileId: myId,
          beerId: allBeers.first.id,
          note: const Value('Sonnenuntergang am Attersee'),
          createdAt: DateTime.utc(2020, 1, 1),
        ));

    final hits = await db
        .watchFeed(onlyProfileId: myId, limit: 30, search: 'attersee')
        .first;

    expect(hits, hasLength(1));
    expect(hits.single.checkin.id, 'gesucht');
  });

  test('Suche findet Bier, Brauerei und Stil – und ignoriert Groß/Klein',
      () async {
    final beer = allBeers.first;
    final brewery = await (db.select(db.breweries)
          ..where((t) => t.id.equals(beer.breweryId)))
        .getSingle();
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'c1',
          profileId: myId,
          beerId: beer.id,
          createdAt: DateTime.utc(2026, 8, 15),
        ));

    for (final term in [
      beer.name.toUpperCase(),
      brewery.name.toLowerCase(),
      beer.style.toUpperCase(),
    ]) {
      final hits = await db.watchFeed(search: term).first;
      expect(hits, hasLength(1), reason: 'Suchbegriff „$term" fand nichts');
    }
  });

  test('Leere Suche verhält sich wie keine Suche', () async {
    await seedCheckins(5);

    expect((await db.watchFeed(search: '').first).length, 5);
    expect((await db.watchFeed(search: '   ').first).length, 5);
  });

  test('Gesamtzahl zählt unabhängig vom Fenster', () async {
    await seedCheckins(50);

    expect(await db.watchCheckinCount(myId).first, 50);
    expect((await db.watchFeed(limit: 10).first).length, 10);
  });
}
