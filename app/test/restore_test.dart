import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/restore.dart';

Map<String, dynamic> _remoteCheckin(
  String id, {
  String beer = 'Goldbräu',
  String? brewery = 'Stiegl',
  String? style = 'Märzen',
  double? rating = 4.5,
  List<String> tags = const ['süffig'],
  String? serving = 'draft',
}) =>
    {
      'id': id,
      'rating': rating,
      'note': 'wiederhergestellt',
      'flavor_tags': tags,
      'serving_style': serving,
      'beer_name': beer,
      'beer_style': style,
      'brewery_name': brewery,
      'is_alcohol_free': false,
      'venue_id': null,
      'venue_name': 'Bräustüberl',
      'created_at': '2026-08-01T18:00:00Z',
    };

void main() {
  late AppDatabase db;
  late String meId;

  setUp(() async {
    db = AppDatabase.memory();
    meId = (await db.getMe()).id;
    await db.into(db.breweries).insert(BreweriesCompanion.insert(
        id: 'br-stiegl', name: 'Stiegl', country: 'AT', city: 'Salzburg'));
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'at-001', breweryId: 'br-stiegl', name: 'Goldbräu',
        style: 'Märzen'));
  });
  tearDown(() => db.close());

  /// Zaehlt, wie oft die teure Abfrage (volle Spalten) lief — der Kern
  /// von Backlog B-2: Bei „nichts Neues" darf sie gar nicht stattfinden.
  var volleAbrufe = 0;

  Future<RestoreSummary> run({
    List<Map<String, dynamic>>? checkins,
    Map<String, DateTime>? badges,
    Map<String, DateTime>? wishlist,
    void Function(Map<String, DateTime>)? onPushBadges,
    void Function(String)? onPushWishlist,
  }) =>
      restoreFromCloud(
        db,
        fetchCheckinIds: () async => checkins == null
            ? null
            : {for (final c in checkins) c['id'] as String},
        fetchCheckinsByIds: (ids) async {
          volleAbrufe++;
          if (checkins == null) return null;
          final gesucht = ids.toSet();
          return [
            for (final c in checkins)
              if (gesucht.contains(c['id'])) c,
          ];
        },
        fetchBadges: () async => badges,
        pushBadges: (rows) async {
          onPushBadges?.call(rows);
          return true;
        },
        fetchWishlist: () async => wishlist,
        pushWishlistItem: (key) async => onPushWishlist?.call(key),
      );

  test('Check-in-Restore ordnet bekannte Biere zu und dedupliziert',
      () async {
    final summary = await run(
      checkins: [_remoteCheckin('11111111-1111-4111-8111-111111111111')],
      badges: const {},
      wishlist: const {},
    );
    expect(summary.checkins, 1);
    expect(summary.complete, isTrue);

    final rows = await db.select(db.checkins).get();
    final restored = rows.single;
    expect(restored.beerId, 'at-001'); // per Name+Brauerei zugeordnet
    expect(restored.profileId, meId);
    expect(restored.flavorTags, 'süffig');
    expect(restored.servingStyle, ServingStyle.draft);
    expect(restored.venueName, 'Bräustüberl');

    // Zweiter Lauf: nichts Neues.
    final again = await run(
      checkins: [_remoteCheckin('11111111-1111-4111-8111-111111111111')],
      badges: const {},
      wishlist: const {},
    );
    expect(again.checkins, 0);
    expect(await db.select(db.checkins).get(), hasLength(1));
  });

  test('Unbekanntes Bier wird als nutzererstellter Eintrag angelegt',
      () async {
    await run(
      checkins: [
        _remoteCheckin('22222222-2222-4222-8222-222222222222',
            beer: 'Kellerblume', brewery: 'Hausbrauerei Blume',
            style: 'Kellerbier'),
      ],
      badges: const {},
      wishlist: const {},
    );
    final beers = await db.select(db.beers).get();
    final created = beers.where((b) => b.name == 'Kellerblume').single;
    expect(created.isUserSubmitted, isTrue);
    expect(created.style, 'Kellerbier');
    final brewery = await (db.select(db.breweries)
          ..where((t) => t.id.equals(created.breweryId)))
        .getSingle();
    expect(brewery.name, 'Hausbrauerei Blume');
  });

  test('Erfolge: Union in beide Richtungen', () async {
    await db.awardBadge(meId, 'erster-schluck', DateTime.utc(2026, 7, 1));
    Map<String, DateTime>? pushed;
    final summary = await run(
      checkins: const [],
      badges: {'kartograph': DateTime.utc(2026, 6, 1)},
      wishlist: const {},
      onPushBadges: (rows) => pushed = rows,
    );
    expect(summary.badges, 1);
    final slugs = await db.earnedBadgeSlugs(meId);
    expect(slugs, containsAll(['erster-schluck', 'kartograph']));
    expect(pushed!.keys, ['erster-schluck']); // lokal-only ging nach oben
  });

  test('Wunschliste: Remote nur für lokal bekannte Biere, Rest hochspiegeln',
      () async {
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'at-002', breweryId: 'br-stiegl', name: 'Paracelsus',
        style: 'Zwickl', isUserSubmitted: const Value(false)));
    await db.toggleWishlist(meId, 'at-002', DateTime.utc(2026, 7, 15));

    final pushedKeys = <String>[];
    final summary = await run(
      checkins: const [],
      badges: const {},
      wishlist: {
        'at-001': DateTime.utc(2026, 6, 10), // lokal bekannt → übernehmen
        'gibt-es-nicht': DateTime.utc(2026, 6, 11), // unbekannt → skip
      },
      onPushWishlist: pushedKeys.add,
    );
    expect(summary.wishlist, 1);
    final items = await (db.select(db.wishlistItems)
          ..where((t) => t.profileId.equals(meId)))
        .get();
    expect(items.map((w) => w.beerId).toSet(), {'at-001', 'at-002'});
    expect(pushedKeys, ['at-002']); // lokal-only ging nach oben
  });

  test('Offline (alle Fetches null) ⇒ complete=false, nichts passiert',
      () async {
    final summary = await run();
    expect(summary.complete, isFalse);
    expect(summary.checkins + summary.badges + summary.wishlist, 0);
    expect(await db.select(db.checkins).get(), isEmpty);
  });

  test('Ist nichts neu, unterbleibt der teure Abruf ganz', () async {
    final zeile = _remoteCheckin('22222222-2222-4222-8222-222222222222');
    final vorher = volleAbrufe; // der Zähler läuft über die Datei

    // Erster Lauf: die Lücke wird geschlossen.
    final erst = await run(checkins: [zeile], badges: const {}, wishlist: const {});
    expect(erst.checkins, 1);
    expect(volleAbrufe - vorher, 1);

    // Zweiter Lauf mit demselben Bestand — der Server hat nichts, was
    // lokal fehlt. Vorher lud die Wiederherstellung hier trotzdem alle
    // Zeilen samt Notizen und Denorm-Feldern und warf sie weg; der
    // Aufwand wuchs mit dem Tagebuch.
    final zweit = await run(checkins: [zeile], badges: const {}, wishlist: const {});
    expect(zweit.checkins, 0);
    expect(volleAbrufe - vorher, 1,
        reason: 'Der zweite Lauf darf die vollen Spalten gar nicht erst '
            'anfordern — nur die ID-Liste.');
    expect(zweit.complete, isTrue,
        reason: 'Nichts zu tun ist ein vollständiger Lauf, kein '
            'übersprungener — sonst liefe die Wiederherstellung ewig '
            'erneut an.');
  });
}
