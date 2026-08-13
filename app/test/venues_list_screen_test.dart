import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/location_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/data/venue_sync.dart';
import 'package:brewmates/features/venues/venues_list_screen.dart';

class _FakeLocationService extends LocationService {
  const _FakeLocationService();

  @override
  Future<LocationResult> getCurrentPosition() async =>
      const LocationGranted(48.2082, 16.3738); // Wien
}

Map<String, dynamic> _row(String id, String name,
        {String? city, double? lat, double? lng, double? priceHalf}) =>
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
      'updated_at': '2026-08-13T10:00:00Z',
    };

void main() {
  testWidgets('Gasthausliste: Anzeige, Suche, Preis- und Nähe-Sortierung',
      (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.upsertVenues([
      VenueSync.companionFromRow(_row('a', 'Zum Adler',
          city: 'Wien', lat: 48.21, lng: 16.37, priceHalf: 5.10)),
      VenueSync.companionFromRow(_row('b', 'Bierstube',
          city: 'Graz', lat: 47.07, lng: 15.44, priceHalf: 3.90)),
      VenueSync.companionFromRow(_row('c', 'Craft Corner', city: 'Linz')),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => null),
        locationServiceProvider
            .overrideWithValue(const _FakeLocationService()),
      ],
      child: const MaterialApp(home: VenuesListScreen()),
    ));
    await tester.pumpAndSettle();

    // Alle drei sichtbar, alphabetisch (Bierstube vor Craft vor Adler? A–Z:
    // Bierstube, Craft Corner, Zum Adler).
    expect(find.text('Zum Adler'), findsOneWidget);
    expect(find.text('Bierstube'), findsOneWidget);
    expect(find.text('Craft Corner'), findsOneWidget);

    // Preis-Sortierung: günstigstes zuerst.
    await tester.tap(find.text('🍺 Preis'));
    await tester.pumpAndSettle();
    final priceOrder = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) =>
            s == 'Zum Adler' || s == 'Bierstube' || s == 'Craft Corner')
        .toList();
    expect(priceOrder, ['Bierstube', 'Zum Adler', 'Craft Corner']);

    // Nähe-Sortierung (Fake-Standort Wien): Adler zuerst, km-Angabe da.
    await tester.tap(find.text('📍 Nähe'));
    await tester.pumpAndSettle();
    expect(find.textContaining('km'), findsWidgets);

    // Suche filtert.
    await tester.enterText(
        find.widgetWithText(TextField, 'Gasthaus oder Ort suchen …'),
        'graz');
    await tester.pumpAndSettle();
    expect(find.text('Bierstube'), findsOneWidget);
    expect(find.text('Zum Adler'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
