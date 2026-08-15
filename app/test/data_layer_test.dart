import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/domain/badges.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    // Die Bier-Datenbank kommt seit dem Ende der Demo-Daten ausschließlich
    // aus den gebündelten Community-Dateien (AT + Bayern).
    await CommunitySync(db).importBundledData();
  });

  tearDown(() => db.close());

  test('Start ohne Demo-Daten: nur eigenes Profil, Biere aus Community-DB',
      () async {
    final beers = await db.select(db.beers).get();
    expect(beers.length, greaterThanOrEqualTo(100));
    expect(beers.where((b) => b.isAlcoholFree).length,
        greaterThanOrEqualTo(3));

    final me = await db.getMe();
    expect(me.username, 'du');
    expect(me.isMe, isTrue);

    // Keine Demo-Freunde, keine Demo-Sessions, keine fremden Check-ins.
    final others =
        await (db.select(db.profiles)..where((t) => t.isMe.equals(false)))
            .get();
    expect(others, isEmpty);
    final active = await db.watchActiveSessions(DateTime.now()).first;
    expect(active, isEmpty);
    expect(await db.select(db.checkins).get(), isEmpty);
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

  test('Community-Sync: JSON parsen und upserten (idempotent)', () async {
    const breweriesJson = '''
    {"version":1,"updated":"2026-08-11","breweries":[{
      "id":"at-test","name":"Testbrauerei","city":"Wien",
      "country":"Österreich","address":"Teststraße 1","latitude":48.2,
      "longitude":16.4,"founded":1900,"website":"https://example.at",
      "ownership":"Testbesitz","employees":10,"annual_output_hl":5000,
      "revenue_eur":null,"profit_eur":null,"energy_notes":null,
      "notes":"Testnotiz","data_status":"Test"}]}''';
    const beersJson = '''
    {"version":1,"updated":"2026-08-11","beers":[{
      "id":"at-test-maerzen","brewery_id":"at-test","name":"Test Märzen",
      "style":"Märzen","abv":5.0,"ibu":null,"is_alcohol_free":false,
      "description_manufacturer":"Süffig.",
      "description_community":"Solide.","community_rating":3.5}]}''';

    final breweryRows = CommunitySync.parseBreweries(breweriesJson);
    final beerRows = CommunitySync.parseBeers(beersJson);
    await db.upsertCommunityData(
        breweryRows: breweryRows, beerRows: beerRows);
    // Zweiter Import derselben Daten darf nichts duplizieren (Upsert).
    await db.upsertCommunityData(
        breweryRows: breweryRows, beerRows: beerRows);

    final found = await db.watchBeers(search: 'test märzen').first;
    expect(found, hasLength(1));
    expect(found.single.beer.communityRating, 3.5);
    expect(found.single.brewery.ownership, 'Testbesitz');

    final located = await db.watchBreweriesWithLocation().first;
    expect(located.map((b) => b.id), contains('at-test'));
  });

  test('Gebündelte Österreich-Datenbank wird importiert', () async {
    final imported = await CommunitySync(db).importBundledData();
    expect(imported, greaterThan(50),
        reason: 'Biere + Brauereien aus allen DACH-Assets');

    final stiegl = await db.watchBrewery('at-stiegl').first;
    expect(stiegl, isNotNull);
    expect(stiegl!.country, 'Österreich');
    expect(stiegl.latitude, isNotNull);

    final goldbraeu = await db.watchBeersOfBrewery('at-stiegl').first;
    expect(goldbraeu, isNotEmpty);
  });

  test('Gebündelte Deutschland-Datenbank (ohne Bayern) wird importiert',
      () async {
    await CommunitySync(db).importBundledData();

    final krombacher = await db.watchBrewery('de-krombacher').first;
    expect(krombacher, isNotNull);
    expect(krombacher!.country, 'Deutschland');
    expect(krombacher.latitude, isNotNull);

    final biere = await db.watchBeersOfBrewery('de-krombacher').first;
    expect(biere, isNotEmpty,
        reason: 'beers-de.json muss Krombacher-Biere enthalten');
  });

  test('Gebündelte Schweiz-Datenbank wird importiert', () async {
    await CommunitySync(db).importBundledData();

    final locher = await db.watchBrewery('ch-locher').first;
    expect(locher, isNotNull);
    expect(locher!.country, 'Schweiz');
    expect(locher.latitude, isNotNull);

    final biere = await db.watchBeersOfBrewery('ch-locher').first;
    expect(biere, isNotEmpty,
        reason: 'beers-ch.json muss Appenzeller-Biere enthalten');
  });

  test('Jede Brauerei aller DACH-Dateien hat eine Kartenposition', () async {
    await CommunitySync(db).importBundledData();
    final alle = await db.watchBreweriesSearch('').first;
    final ohnePosition =
        alle.where((b) => b.latitude == null || b.longitude == null).toList();
    expect(ohnePosition, isEmpty,
        reason: 'ohne Koordinaten fehlt die Brauerei auf der Karte: '
            '${ohnePosition.map((b) => b.id).toList()}');
  });

  test('parseBeers übernimmt Barcodes aus der Community-DB', () async {
    const beersJson = '''
    {"version":2,"updated":"2026-08-12","beers":[{
      "id":"at-barcode-test","brewery_id":"at-test","name":"Barcode-Bier",
      "style":"Pils","abv":5.0,"ibu":null,"is_alcohol_free":false,
      "barcodes":["90034107","9003400304939"],
      "description_manufacturer":null,
      "description_community":null,"community_rating":null}]}''';
    final rows = CommunitySync.parseBeers(beersJson);
    expect(rows.single.barcodes.value, '90034107,9003400304939');
  });

  test('parseBeers übernimmt Etikett-Bild-URLs (image_url)', () async {
    const beersJson = '''
    {"version":3,"updated":"2026-08-13","beers":[{
      "id":"at-bild-test","brewery_id":"at-test","name":"Bild-Bier",
      "style":"Pils","abv":5.0,"ibu":null,"is_alcohol_free":false,
      "barcodes":["90034107"],
      "image_url":"https://images.openfoodfacts.org/images/products/test.jpg",
      "description_manufacturer":null,
      "description_community":null,"community_rating":null}]}''';
    final rows = CommunitySync.parseBeers(beersJson);
    expect(rows.single.imageUrl.value,
        'https://images.openfoodfacts.org/images/products/test.jpg');
    // Ohne image_url bleibt das Feld null (kein Pflichtfeld).
    const ohneBild = '''
    {"version":3,"updated":"2026-08-13","beers":[{
      "id":"at-ohne-bild","brewery_id":"at-test","name":"Ohne Bild",
      "style":"Pils","abv":5.0,"ibu":null,"is_alcohol_free":false,
      "description_manufacturer":null,
      "description_community":null,"community_rating":null}]}''';
    expect(CommunitySync.parseBeers(ohneBild).single.imageUrl.value, isNull);
  });

  test('Gebündelte Bayern-Datenbank wird importiert', () async {
    await CommunitySync(db).importBundledData();

    final augustiner = await db.watchBrewery('de-by-augustiner').first;
    expect(augustiner, isNotNull);
    expect(augustiner!.country, 'Deutschland');
    expect(augustiner.latitude, isNotNull);

    final biere = await db.watchBeersOfBrewery('de-by-augustiner').first;
    expect(biere, isNotEmpty,
        reason: 'beers-by.json muss Augustiner-Biere enthalten');
  });

  test('Brauerei-Suche findet nach Name, Ort und Land', () async {
    await CommunitySync(db).importBundledData();

    final byName = await db.watchBreweriesSearch('augustiner').first;
    expect(byName.map((b) => b.id), contains('de-by-augustiner'));

    final byCity = await db.watchBreweriesSearch('salzburg').first;
    expect(byCity, isNotEmpty, reason: 'Stiegl sitzt in Salzburg');

    final byCountry = await db.watchBreweriesSearch('deutschland').first;
    expect(byCountry.length, greaterThanOrEqualTo(20),
        reason: '23 bayerische Brauereien');
  });

  test('Gebündelte DB: Stiegl-Goldbräu ist per Barcode auffindbar',
      () async {
    await CommunitySync(db).importBundledData();
    final found = await db.findBeerByBarcode('90034107');
    expect(found, isNotNull);
    expect(found!.beer.name, contains('Goldbräu'));

    // Session ohne Venue (Beacon-Fall) ist gültig.
    final me = await db.getMe();
    await db.into(db.sessions).insert(SessionsCompanion.insert(
          id: 'beacon-session',
          hostId: me.id,
          visibility: SessionVisibility.friends,
          status: SessionStatus.active,
          startedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 3)),
        ));
    final active = await db.getMyActiveSession(me.id, DateTime.now());
    expect(active, isNotNull);
    expect(active!.venueName, isNull);
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
