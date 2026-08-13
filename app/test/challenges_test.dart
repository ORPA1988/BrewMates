import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/domain/challenges.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Profile me;

  final windowStart = DateTime(2026, 8, 1);
  final windowEnd = DateTime(2026, 9, 1);

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    me = await db.getMe();
  });

  tearDown(() => db.close());

  Future<void> cacheChallenge(String id, Map<String, dynamic> rule) =>
      db.upsertChallengeCache([
        ChallengeCacheCompanion(
          id: Value(id),
          title: Value('Test-Challenge $id'),
          description: const Value('Testlauf'),
          emoji: const Value('🏆'),
          ruleJson: Value(json.encode(rule)),
          startsAt: Value(windowStart),
          endsAt: Value(windowEnd),
        ),
      ]);

  Future<void> checkin(String id, String beerId, DateTime at,
      {String? venueId, String? venueName}) =>
      db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: id,
            profileId: me.id,
            beerId: beerId,
            venueId: Value(venueId),
            venueName: Value(venueName),
            createdAt: at,
          ));

  test('Regeltypen zählen korrekt und nur im Zeitfenster', () async {
    final beers = await db.select(db.beers).get();
    final styles = <String, Beer>{};
    for (final b in beers) {
      styles.putIfAbsent(b.style, () => b);
      if (styles.length == 3) break;
    }
    final three = styles.values.toList();

    var i = 0;
    for (final beer in three) {
      await checkin('in-window-${i++}', beer.id, DateTime(2026, 8, 10 + i));
    }
    // Außerhalb des Fensters: darf nicht zählen.
    await checkin('outside-1', three.first.id, DateTime(2026, 7, 20));
    await checkin('outside-2', three.first.id, DateTime(2026, 9, 2));

    await cacheChallenge(
        'aaaaaaaa-0000-0000-0000-000000000001', {
      'type': 'distinct_styles',
      'threshold': 3,
    });
    await cacheChallenge(
        'bbbbbbbb-0000-0000-0000-000000000002', {
      'type': 'checkins_count',
      'threshold': 10,
    });

    final progress = await ChallengeEngine(db)
        .progressList(me.id, now: DateTime(2026, 8, 15));
    final styleChallenge = progress
        .singleWhere((p) => p.def.id.startsWith('aaaaaaaa'));
    expect(styleChallenge.progress, 3, reason: 'nur Fenster-Check-ins');
    final countChallenge = progress
        .singleWhere((p) => p.def.id.startsWith('bbbbbbbb'));
    expect(countChallenge.progress, 3);
    expect(countChallenge.completed, isFalse);
  });

  test('style_specific ist case-insensitive, venue_checkins zählt Orte',
      () async {
    final beers = await db.select(db.beers).get();
    final pils = beers.where((b) => b.style.toLowerCase().contains('pils'));
    expect(pils.length, greaterThanOrEqualTo(2));
    var i = 0;
    for (final beer in pils.take(2)) {
      await checkin('pils-${i++}', beer.id, DateTime(2026, 8, 5),
          venueId: 'venue-$i');
    }

    await cacheChallenge('cccccccc-0000-0000-0000-000000000003',
        {'type': 'style_specific', 'threshold': 2, 'style': 'PILS'});
    await cacheChallenge('dddddddd-0000-0000-0000-000000000004',
        {'type': 'venue_checkins', 'threshold': 2});

    final completed = await ChallengeEngine(db)
        .evaluate(me.id, now: DateTime(2026, 8, 15));
    expect(completed.map((d) => d.id.substring(0, 8)).toSet(),
        {'cccccccc', 'dddddddd'});

    // Zweiter Lauf vergibt nichts erneut (Badge existiert schon).
    final again = await ChallengeEngine(db)
        .evaluate(me.id, now: DateTime(2026, 8, 16));
    expect(again, isEmpty);

    // Badge-Slug-Format prüfen.
    final slugs = await db.earnedBadgeSlugs(me.id);
    expect(slugs, contains('challenge-cccccccc'));
  });

  test('Unbekannter Regeltyp crasht nicht und vergibt nichts', () async {
    await cacheChallenge('eeeeeeee-0000-0000-0000-000000000005',
        {'type': 'zukunftsmusik', 'threshold': 1});
    final completed = await ChallengeEngine(db)
        .evaluate(me.id, now: DateTime(2026, 8, 15));
    expect(completed, isEmpty);
    final progress = await ChallengeEngine(db)
        .progressList(me.id, now: DateTime(2026, 8, 15));
    expect(progress.where((p) => p.def.id.startsWith('eeeeeeee')), isEmpty);
  });
}
