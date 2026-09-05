// Die redaktionelle Einschätzung darf nicht wie eine Messung aussehen
// (Meldung #143). Sterne gibt es nur noch für echte Bewertungen.
//
// Baut seine Daten mit `AppDatabase.memory()` auf — die gibt es nur auf
// der VM (siehe `quick_checkin_test.dart`).
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/beers/beer_detail_screen.dart';
import 'package:brewmates/widgets/rating_stars.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await db.into(db.breweries).insert(BreweriesCompanion.insert(
        id: 'br1', name: 'Testbrauerei', country: 'AT', city: 'Wien'));
    await db.into(db.beers).insert(BeersCompanion.insert(
          id: 'b1',
          breweryId: 'br1',
          name: 'Testbier',
          style: 'Märzen',
          communityRating: const Value(3.4),
          descriptionCommunity:
              const Value('Weich, malzig, mit sanfter Süße im Abgang.'),
        ));
  });

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: BeerDetailScreen(beerId: 'b1')),
    ));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  /// Baut den Baum ab und lässt Drift seine Stream-Timer aufräumen.
  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Die redaktionelle Schätzung erscheint nicht als Sterne',
      (tester) async {
    await zeige(tester);

    // Ohne echte Bewertung und ohne eigenen Check-in gibt es kein
    // Sternebild — die 3,4 aus der Datenbank ist keine Messung.
    expect(find.byType(RatingStars), findsNothing);
    expect(find.textContaining('3.4'), findsNothing);

    await abbauen(tester);
  });

  testWidgets('Stattdessen steht dort der geschriebene Satz',
      (tester) async {
    await zeige(tester);

    expect(find.text('Redaktionelle Einschätzung'), findsOneWidget);
    expect(find.textContaining('Weich, malzig'), findsOneWidget);
    // „Erfahrungen aus der Community" behauptete eine fremde Quelle,
    // die es nie gab.
    expect(find.textContaining('Erfahrungen aus der Community'), findsNothing);

    await abbauen(tester);
  });
}
