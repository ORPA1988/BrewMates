import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/venue_sync.dart';

Map<String, dynamic> _row(String id, String name,
        {String? city,
        double? lat,
        double? lng,
        double? priceHalf,
        String? updatedAt}) =>
    {
      'id': id,
      'name': name,
      'category': 'gasthaus',
      'address': null,
      'city': city,
      'latitude': lat,
      'longitude': lng,
      'opening_hours': null,
      'price_half_l': priceHalf,
      'price_third_l': null,
      'verified': false,
      'created_by': null,
      'updated_at': updatedAt ?? '2026-08-13T10:00:00Z',
    };

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('Venue-Cache: Upsert ist idempotent und Delta-Stand wird erkannt',
      () async {
    final rows = [
      VenueSync.companionFromRow(_row('v1', 'Hopfengarten',
          city: 'Wien', lat: 48.2, lng: 16.37, priceHalf: 4.2)),
      VenueSync.companionFromRow(
          _row('v2', 'Craft Corner', updatedAt: '2026-08-13T11:30:00Z')),
    ];
    await db.upsertVenues(rows);
    await db.upsertVenues(rows); // doppelt darf nichts duplizieren
    final all = await db.select(db.venues).get();
    expect(all, hasLength(2));

    // Drift liefert den Zeitpunkt ohne UTC-Flag zurück – der Moment zählt.
    final latest = await db.latestVenueUpdate();
    expect(latest!.millisecondsSinceEpoch,
        DateTime.utc(2026, 8, 13, 11, 30).millisecondsSinceEpoch);
  });

  test('Nur Venues mit Koordinaten erscheinen auf der Karte', () async {
    await db.upsertVenues([
      VenueSync.companionFromRow(
          _row('v1', 'Mit Position', lat: 48.2, lng: 16.37)),
      VenueSync.companionFromRow(_row('v2', 'Ohne Position')),
    ]);
    final located = await db.watchVenuesWithLocation().first;
    expect(located.map((v) => v.id), ['v1']);
  });

  test('Venue-Suche findet nach Name und Ort', () async {
    await db.upsertVenues([
      VenueSync.companionFromRow(_row('v1', 'Hopfengarten', city: 'Wien')),
      VenueSync.companionFromRow(_row('v2', 'Bierstube', city: 'Graz')),
    ]);
    expect((await db.watchVenueSearch('hopfen').first).single.id, 'v1');
    expect((await db.watchVenueSearch('graz').first).single.id, 'v2');
    expect(await db.watchVenueSearch('').first, hasLength(2));
  });
}
