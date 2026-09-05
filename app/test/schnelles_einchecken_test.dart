// Einchecken ohne Barcode: Reihenfolge der Treffer und die Vorschläge
// bei leerem Suchfeld (Wunsch #139).
//
// Der Widget-Teil baut seine Daten mit `AppDatabase.memory()` auf — die
// gibt es nur auf der VM (siehe `quick_checkin_test.dart`).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/beer_suche.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/checkin/checkin_screen.dart';

void main() {
  group('Trefferreihenfolge', () {
    int rang(String name, String brauerei, String suche,
            {String stil = 'Lager'}) =>
        trefferRang(
            name: name, brauerei: brauerei, stil: stil, suche: suche);

    test('Name am Anfang schlägt Name in der Mitte', () {
      expect(rang('Gösser Märzen', 'Gösser', 'gö'),
          lessThan(rang('Zwickl Gösser Art', 'Stiegl', 'gö')));
    });

    test('Zweites Wort im Namen schlägt die Brauerei', () {
      expect(rang('Stiegl Goldbräu', 'Stiegl', 'gold'),
          lessThan(rang('Märzen', 'Goldbräu Wien', 'gold')));
    });

    test('Brauerei schlägt den Stil', () {
      expect(rang('Märzen', 'Pilsner Urquell', 'pils'),
          lessThan(rang('Hausbier', 'Ottakringer', 'pils', stil: 'Pils')));
    });

    test('Trennzeichen zerlegen den Namen', () {
      // „Zwickl-Bier“: das zweite Wort zählt, obwohl kein Leerzeichen
      // davor steht.
      expect(rang('Zwickl-Bier', 'Hirter', 'bier'), 1);
    });

    test('Ohne Suchbegriff sind alle gleich', () {
      expect(rang('Aaa', 'Bbb', '   '), rang('Zzz', 'Yyy', ''));
    });
  });

  group('Bier-Auswahl im Check-in', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.memory();
      await db.into(db.breweries).insert(BreweriesCompanion.insert(
          id: 'br1', name: 'Testbrauerei', country: 'AT', city: 'Wien'));
      await db.into(db.beers).insert(BeersCompanion.insert(
          id: 'goe', breweryId: 'br1', name: 'Gösser Märzen', style: 'Märzen'));
      await db.into(db.beers).insert(BeersCompanion.insert(
          id: 'zwi',
          breweryId: 'br1',
          name: 'Aaa Zwickl Gösser Art',
          style: 'Zwickl'));
    });

    /// Baut den Baum ab und laesst Drift seine Stream-Timer aufraeumen —
    /// sonst meldet der Test „Pending timers" statt eines Ergebnisses
    /// (dasselbe Muster wie in `map_screen_test.dart`).
    Future<void> abbauen(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    }

    Future<void> zeigeSuche(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineServiceProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: CheckinScreen()),
      ));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    testWidgets('leeres Feld zeigt das zuletzt getrunkene Bier',
        (tester) async {
      final me = await db.getMe();
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: 'c1',
            profileId: me.id,
            beerId: 'goe',
            createdAt: DateTime(2026, 9, 1, 20),
          ));

      await zeigeSuche(tester);

      expect(find.text('Zuletzt getrunken'), findsOneWidget);
      expect(find.text('Gösser Märzen'), findsOneWidget);
      // Ohne Check-in kein Vorschlag: Die Liste ist die eigene
      // Vergangenheit, nicht der halbe Katalog.
      expect(find.text('Aaa Zwickl Gösser Art'), findsNothing);
      await abbauen(tester);
    });

    testWidgets('getippte Anfangsbuchstaben stehen oben', (tester) async {
      await zeigeSuche(tester);
      await tester.enterText(find.byType(TextField).first, 'gö');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      // Alphabetisch käme „Aaa Zwickl Gösser Art“ zuerst — genau das
      // soll die Rangfolge verhindern.
      final treffer = tester.widgetList<ListTile>(find.byType(ListTile));
      expect((treffer.first.title! as Text).data, 'Gösser Märzen');
      await abbauen(tester);
    });

    testWidgets('kein Treffer führt zum Anlegen', (tester) async {
      await zeigeSuche(tester);
      await tester.enterText(find.byType(TextField).first, 'Sudpfanne');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Bier anlegen'), findsOneWidget);
      await abbauen(tester);
    });
  });
}
