import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';

/// Hintergrundgeschichten: Import, Anzeige-Bedingung und die Regel
/// „erst beim ersten Mal".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
  });

  tearDown(() => db.close());

  test('Geschichten landen beim Import in der Datenbank', () async {
    final withStory = await (db.select(db.breweries)
          ..where((t) => t.story.isNotNull()))
        .get();

    expect(withStory, isNotEmpty,
        reason: 'Keine Brauerei-Geschichte importiert');
    // Stichprobe: Weihenstephan, die älteste im Bestand.
    final weihenstephan = await (db.select(db.breweries)
          ..where((t) => t.id.equals('de-by-weihenstephan')))
        .getSingle();
    expect(weihenstephan.story, isNotNull);
    expect(weihenstephan.story, contains('1040'));
  });

  test('Geschichten bleiben unter der Serverlänge von 1200 Zeichen',
      () async {
    // Migration 0023 setzt diese Grenze — überlange Texte würden beim
    // Upload abgelehnt.
    for (final b in await db.select(db.breweries).get()) {
      expect((b.story ?? '').length, lessThanOrEqualTo(1200),
          reason: 'Brauerei ${b.id}');
    }
    for (final b in await db.select(db.beers).get()) {
      expect((b.story ?? '').length, lessThanOrEqualTo(1200),
          reason: 'Bier ${b.id}');
    }
  });

  test('Ohne Geschichte bleibt das Feld leer statt leerer Zeichenkette',
      () async {
    // Eine leere Zeichenkette würde die Anzeige zu einer leeren
    // Überschrift verleiten.
    final all = await db.select(db.breweries).get();
    expect(all.where((b) => b.story?.isEmpty ?? false), isEmpty);
  });

  test('„Erstes Mal" erkennt man am fehlenden eigenen Check-in', () async {
    final me = await db.getMe();
    final beer = (await db.select(db.beers).get()).first;

    expect(await db.hasCheckinForBeer(me.id, beer.id), isFalse);

    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'c1',
          profileId: me.id,
          beerId: beer.id,
          createdAt: DateTime.utc(2026, 8, 15),
        ));

    expect(await db.hasCheckinForBeer(me.id, beer.id), isTrue);
    // Ein anderes Bier bleibt „neu".
    final other = (await db.select(db.beers).get())[1];
    expect(await db.hasCheckinForBeer(me.id, other.id), isFalse);
  });

  test('Der Check-in eines anderen macht das Bier nicht bekannt', () async {
    final beer = (await db.select(db.beers).get()).first;
    await db.into(db.profiles).insert(ProfilesCompanion.insert(
          id: 'fremd',
          username: 'fremd',
          displayName: 'Fremd',
        ));
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'c1',
          profileId: 'fremd',
          beerId: beer.id,
          createdAt: DateTime.utc(2026, 8, 15),
        ));

    final me = await db.getMe();
    expect(await db.hasCheckinForBeer(me.id, beer.id), isFalse);
  });
}
