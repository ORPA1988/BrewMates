import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/data/venue_sync.dart';
import 'package:brewmates/widgets/venue_picker.dart';

void main() {
  testWidgets('Venue-Picker: Suche, Auswahl und Freitext-Fallback (offline)',
      (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    VenueSelection? result;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async =>
                    result = await showVenuePicker(context),
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await db.upsertVenues([
      VenueSync.companionFromRow({
        'id': 'v1',
        'name': 'Hopfengarten',
        'category': 'biergarten',
        'address': null,
        'city': 'Wien',
        'latitude': null,
        'longitude': null,
        'opening_hours': null,
        'price_half_l': 4.2,
        'price_third_l': null,
        'verified': true,
        'created_by': null,
        'updated_at': '2026-08-13T10:00:00Z',
      }),
    ]);

    // Treffer auswählen
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Gasthaus suchen oder Ort eintippen'),
        'hopfen');
    await tester.pumpAndSettle();
    expect(find.text('Hopfengarten'), findsOneWidget);
    await tester.tap(find.text('Hopfengarten'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.venueId, 'v1');
    expect(result!.venueName, 'Hopfengarten');

    // Freitext-Fallback
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Gasthaus suchen oder Ort eintippen'),
        'Bei Oma im Garten');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('als Freitext verwenden'));
    await tester.pumpAndSettle();
    expect(result!.venueId, isNull);
    expect(result!.venueName, 'Bei Oma im Garten');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
