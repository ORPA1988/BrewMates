// Die Gebindegröße hängt am Barcode — und wo ein Bier nur eine kennt,
// gilt sie auch ohne Scan (Wunsch #144).
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/checkin/checkin_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await db.into(db.breweries).insert(BreweriesCompanion.insert(
        id: 'br1', name: 'Testbrauerei', country: 'AT', city: 'Wien'));
    // Ein Bier mit zwei EANs derselben Größe: eindeutig.
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'eindeutig',
        breweryId: 'br1',
        name: 'Nur Halbe',
        style: 'Märzen',
        barcodes: const Value('90000019,90000026')));
    // Eines mit zwei verschiedenen Größen: nicht eindeutig.
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'zweideutig',
        breweryId: 'br1',
        name: 'Halbe und Seidl',
        style: 'Lager',
        barcodes: const Value('90000033,90000040')));
    // Und eines ganz ohne Barcode.
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'ohne', breweryId: 'br1', name: 'Vom Fass', style: 'Zwickl'));

    await db.setBarcodeVolumes({
      '90000019': 500,
      '90000026': 500,
      '90000033': 330,
      '90000040': 500,
    });
  });

  group('eindeutigeGebindegroesse', () {
    test('Eine Größe an allen Codes: die gilt', () async {
      expect(await db.eindeutigeGebindegroesse('eindeutig'), 500);
    });

    test('Zwei verschiedene Größen: keine Antwort statt einer geratenen',
        () async {
      expect(await db.eindeutigeGebindegroesse('zweideutig'), isNull);
    });

    test('Ohne Barcode gibt es nichts nachzuschlagen', () async {
      expect(await db.eindeutigeGebindegroesse('ohne'), isNull);
    });

    test('Unbekanntes Bier führt nicht zu einem Fehler', () async {
      expect(await db.eindeutigeGebindegroesse('gibtsnicht'), isNull);
    });

    tearDown(() => db.close());
  });

  group('Check-in ohne Scan', () {
    Future<void> zeige(WidgetTester tester, String beerId) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineServiceProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(home: CheckinScreen(preselectedBeerId: beerId)),
      ));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    Future<void> abbauen(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    }

    testWidgets('Eindeutige Größe steht schon da, mit Begründung',
        (tester) async {
      await zeige(tester, 'eindeutig');

      final chip = tester.widget<ChoiceChip>(find.ancestor(
          of: find.text('0,5 l'), matching: find.byType(ChoiceChip)));
      expect(chip.selected, isTrue);
      expect(find.textContaining('aus der Bierdatenbank'), findsOneWidget);

      await abbauen(tester);
    });

    testWidgets('Bei zwei Größen bleibt die Wahl offen', (tester) async {
      await zeige(tester, 'zweideutig');

      for (final label in ['0,33 l', '0,5 l']) {
        final chip = tester.widget<ChoiceChip>(find.ancestor(
            of: find.text(label), matching: find.byType(ChoiceChip)));
        expect(chip.selected, isFalse, reason: '$label darf nicht gesetzt sein');
      }
      expect(find.textContaining('aus der Bierdatenbank'), findsNothing);

      await abbauen(tester);
    });
  });
}
