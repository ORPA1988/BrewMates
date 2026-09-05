// Sortierung in Entdecken (Wunsch #145): Biere und Brauereien lassen
// sich jetzt genauso ordnen wie Gasthäuser.
//
// Der Widget-Teil baut seine Daten mit `AppDatabase.memory()` auf — die
// gibt es nur auf der VM (siehe `quick_checkin_test.dart`).
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:brewmates/data/beer_sort.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/discover/discover_screen.dart';

/// Wien, als Bezugspunkt für die Entfernungen.
const _hier = LatLng(48.2082, 16.3738);

Brewery _brauerei(String id, String name, {double? lat, double? lng}) =>
    Brewery(
      id: id,
      name: name,
      country: 'AT',
      city: 'Ort',
      latitude: lat,
      longitude: lng,
    );

Beer _bier(String id, String name, String brauereiId,
        {String style = 'Lager', double? abv}) =>
    Beer(
      id: id,
      breweryId: brauereiId,
      name: name,
      style: style,
      abv: abv,
      isAlcoholFree: false,
      isUserSubmitted: false,
      barcodes: '',
    );

void main() {
  group('sortBeers', () {
    // Wien, Salzburg (~250 km), und eine Brauerei ohne Koordinaten.
    final wien = _brauerei('b-wien', 'Wiener Brauerei', lat: 48.2, lng: 16.37);
    final salzburg =
        _brauerei('b-sbg', 'Salzburger Brauerei', lat: 47.8, lng: 13.05);
    final ohneOrt = _brauerei('b-x', 'Brauerei ohne Ort');

    final liste = [
      BeerWithBrewery(beer: _bier('3', 'Zeta', 'b-x', abv: 4.0), brewery: ohneOrt),
      BeerWithBrewery(
          beer: _bier('2', 'Beta', 'b-sbg', abv: null), brewery: salzburg),
      BeerWithBrewery(
          beer: _bier('1', 'Alpha', 'b-wien', abv: 7.5), brewery: wien),
    ];

    test('A–Z ordnet nach dem Biernamen', () {
      final s = sortBeers(liste, BeerSort.alphabetical);
      expect(s.map((e) => e.beer.name), ['Alpha', 'Beta', 'Zeta']);
    });

    test('Nähe rechnet über die Brauerei, ohne Ort ans Ende', () {
      final s = sortBeers(liste, BeerSort.distance, here: _hier);
      expect(s.map((e) => e.beer.name), ['Alpha', 'Beta', 'Zeta']);
      // Nicht weil A–Z: Ohne Standort stünde Zeta zwischen den anderen.
      expect(breweryDistanceKm(ohneOrt, _hier), isNull);
    });

    test('Alkohol aufsteigend, ohne Angabe ans Ende', () {
      final s = sortBeers(liste, BeerSort.abv);
      expect(s.map((e) => e.beer.name), ['Zeta', 'Alpha', 'Beta']);
    });

    test('Bei gleichem Rang entscheidet der Name', () {
      final gleich = [
        BeerWithBrewery(beer: _bier('b', 'Bravo', 'b-x', abv: 5.0),
            brewery: ohneOrt),
        BeerWithBrewery(beer: _bier('a', 'Alfa', 'b-x', abv: 5.0),
            brewery: ohneOrt),
      ];
      expect(sortBeers(gleich, BeerSort.abv).map((e) => e.beer.name),
          ['Alfa', 'Bravo']);
    });

    test('Ohne Standort bleibt Nähe eine stabile Reihenfolge', () {
      // Alle Entfernungen null → alles gleichrangig → Name entscheidet.
      final s = sortBeers(liste, BeerSort.distance);
      expect(s.map((e) => e.beer.name), ['Alpha', 'Beta', 'Zeta']);
    });
  });

  group('sortBreweries', () {
    final wien = _brauerei('b-wien', 'Zeta Wien', lat: 48.2, lng: 16.37);
    final salzburg = _brauerei('b-sbg', 'Alfa Salzburg', lat: 47.8, lng: 13.05);
    final ohneOrt = _brauerei('b-x', 'Mitte ohne Ort');
    final liste = [ohneOrt, wien, salzburg];

    test('Nähe: die nächste zuerst, ohne Ort ans Ende', () {
      final s = sortBreweries(liste, BrewerySort.distance, here: _hier);
      expect(s.map((e) => e.name),
          ['Zeta Wien', 'Alfa Salzburg', 'Mitte ohne Ort']);
    });

    test('A–Z ignoriert den Standort', () {
      final s = sortBreweries(liste, BrewerySort.alphabetical, here: _hier);
      expect(s.map((e) => e.name),
          ['Alfa Salzburg', 'Mitte ohne Ort', 'Zeta Wien']);
    });
  });

  group('Entdecken', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.memory();
      await db.into(db.breweries).insert(BreweriesCompanion.insert(
          id: 'br1', name: 'Testbrauerei', country: 'AT', city: 'Wien'));
      await db.into(db.beers).insert(BeersCompanion.insert(
          id: 'b1',
          breweryId: 'br1',
          name: 'Testbier',
          style: 'Lager',
          abv: const Value(5.0)));
    });

    Future<void> zeige(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineServiceProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: DiscoverScreen()),
      ));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    Future<void> abbauen(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    }

    testWidgets('Die Bierliste hat eine Sortierleiste', (tester) async {
      await zeige(tester);
      expect(find.text('A–Z'), findsOneWidget);
      expect(find.text('% Alkohol'), findsOneWidget);
      await abbauen(tester);
    });

    testWidgets('Nähe ist ohne Standort gesperrt, nicht verschwunden',
        (tester) async {
      await zeige(tester);
      // Im Test gibt es keinen Standort: Der Chip steht da, ist aber
      // nicht wählbar — ein verschwundener Chip sähe aus wie ein Fehler.
      expect(find.text('📍 Nähe'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
          find.ancestor(of: find.text('📍 Nähe'), matching: find.byType(ChoiceChip)));
      expect(chip.onSelected, isNull);
      await abbauen(tester);
    });
  });
}
