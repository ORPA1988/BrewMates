import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/domain/badges.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() => db.close());

  test('Seed liefert Bier-Datenbank, Freunde und Aktivität', () async {
    final beers = await db.select(db.beers).get();
    expect(beers.length, greaterThanOrEqualTo(30));
    expect(beers.where((b) => b.isAlcoholFree).length,
        greaterThanOrEqualTo(3));

    final me = await db.getMe();
    expect(me.username, 'du');
    expect(me.isMe, isTrue);

    final friends =
        await (db.select(db.profiles)..where((t) => t.isMe.equals(false)))
            .get();
    expect(friends.length, 3);

    // Annas Session ist aktiv und auf der Karte sichtbar.
    final active = await db.watchActiveSessions(DateTime.now()).first;
    expect(active, isNotEmpty);
    expect(active.first.host.username, 'anna_hops');
  });

  test('Erster Check-in vergibt „Erster Schluck" – genau einmal', () async {
    final me = await db.getMe();
    final beer = (await db.select(db.beers).get()).first;
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'test-checkin-1',
          profileId: me.id,
          beerId: beer.id,
          rating: const Value(4.0),
          createdAt: DateTime.now(),
        ));

    final earned = await BadgeEngine(db).evaluate(me.id);
    expect(earned.map((b) => b.slug), contains('erster-schluck'));

    // Zweite Auswertung darf nichts erneut vergeben.
    final again = await BadgeEngine(db).evaluate(me.id);
    expect(again, isEmpty);
  });

  test('Stil-Entdecker braucht 5 verschiedene Stile', () async {
    final me = await db.getMe();
    final beers = await db.select(db.beers).get();
    final distinctStyles = <String, Beer>{};
    for (final b in beers) {
      distinctStyles.putIfAbsent(b.style, () => b);
      if (distinctStyles.length == 5) break;
    }
    var i = 0;
    for (final beer in distinctStyles.values) {
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: 'style-checkin-${i++}',
            profileId: me.id,
            beerId: beer.id,
            createdAt: DateTime.now(),
          ));
    }

    final progress = await BadgeEngine(db).progressList(me.id);
    final stilEntdecker =
        progress.singleWhere((p) => p.def.slug == 'stil-entdecker');
    expect(stilEntdecker.progress, 5);

    final earned = await db.earnedBadgeSlugs(me.id);
    expect(earned, isEmpty); // evaluate wurde noch nicht aufgerufen
    await BadgeEngine(db).evaluate(me.id);
    expect(await db.earnedBadgeSlugs(me.id), contains('stil-entdecker'));
  });

  test('Abgelaufene Sessions werden serverseitig beendet', () async {
    final me = await db.getMe();
    final now = DateTime.now();
    await db.into(db.sessions).insert(SessionsCompanion.insert(
          id: 'test-session-expired',
          hostId: me.id,
          venueName: const Value('Testgarten'),
          visibility: SessionVisibility.friends,
          status: SessionStatus.active,
          startedAt: now.subtract(const Duration(hours: 4)),
          expiresAt: now.subtract(const Duration(hours: 1)),
        ));

    expect(await db.getMyActiveSession(me.id, now), isNull,
        reason: 'expires_at liegt in der Vergangenheit');

    await db.endExpiredSessions(now);
    final row = await (db.select(db.sessions)
          ..where((t) => t.id.equals('test-session-expired')))
        .getSingle();
    expect(row.status, SessionStatus.ended);
    expect(row.endedAt, isNotNull);
  });

  test('Statistiken zählen einzigartige Werte', () async {
    final me = await db.getMe();
    final beer = (await db.select(db.beers).get()).first;
    for (var i = 0; i < 3; i++) {
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: 'dup-checkin-$i',
            profileId: me.id,
            beerId: beer.id,
            venueName: const Value('Immer dieselbe Bar'),
            createdAt: DateTime.now(),
          ));
    }
    final stats = await db.computeProfileStats(me.id);
    expect(stats.totalCheckins, 3);
    expect(stats.uniqueBeers, 1);
    expect(stats.uniqueVenues, 1);
  });

  test('Wunschliste lässt sich togglen', () async {
    final me = await db.getMe();
    final beer = (await db.select(db.beers).get()).first;
    final now = DateTime.now();

    await db.toggleWishlist(me.id, beer.id, now);
    expect(await db.watchOnWishlist(me.id, beer.id).first, isTrue);
    await db.toggleWishlist(me.id, beer.id, now);
    expect(await db.watchOnWishlist(me.id, beer.id).first, isFalse);
  });

  test('Community-Bier anlegen und finden', () async {
    final brewery = await db.getOrCreateBrewery(
      id: 'test-brewery',
      name: 'Test-Bräu',
      country: 'Deutschland',
      city: 'Teststadt',
    );
    await db.addBeer(
      id: 'test-beer',
      breweryId: brewery.id,
      name: 'Testbier Hell',
      style: 'Helles',
      abv: 5.0,
    );
    final found = await db.watchBeers(search: 'testbier').first;
    expect(found, hasLength(1));
    expect(found.single.beer.isUserSubmitted, isTrue);
    expect(found.single.brewery.name, 'Test-Bräu');
  });
}
