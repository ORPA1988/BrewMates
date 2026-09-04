// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/widgets/rating_input.dart';

/// Eine Bewertung entsteht nur durch einen Tipp.
///
/// **Der Fehler, den das ablöst:** Der Check-in-Bildschirm startete mit
/// `_rating = 3.5` und schrieb den Wert immer mit. Wer ein Bier nur
/// eintrug, ohne es beurteilen zu wollen, hat es damit beurteilt — mit
/// 3,5. Das verzerrt systematisch in eine Richtung, und zwar alles, was
/// auf Bewertungen aufbaut: den eigenen Durchschnitt, die Statistik und
/// über `beer_rating_stats` die Community-Bewertung, die anderen
/// angezeigt wird. Ein Bier mit fünf beiläufigen Check-ins sah aus wie
/// ein solide mittelmäßiges Bier, obwohl niemand es je beurteilt hat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  group('Die Sterne', () {
    Future<double?> getippt(WidgetTester tester,
        {required int stern, required bool linkeHaelfte}) async {
      double? ergebnis;
      var gerufen = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RatingInput(
            rating: null,
            size: 40,
            onChanged: (w) {
              ergebnis = w;
              gerufen = true;
            },
          ),
        ),
      ));
      final ziel = tester.getTopLeft(find.byType(GestureDetector).at(stern));
      await tester.tapAt(Offset(ziel.dx + (linkeHaelfte ? 8 : 32), ziel.dy + 20));
      await tester.pump();
      expect(gerufen, isTrue);
      return ergebnis;
    }

    testWidgets('ohne Tipp gibt es keine Bewertung', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RatingInput(rating: null, onChanged: (_) {}),
        ),
      ));
      expect(find.text('Noch nicht bewertet'), findsOneWidget);
      // Kein Zurücknehmen-Knopf: Es gibt nichts zurückzunehmen.
      expect(find.byTooltip('Bewertung zurücknehmen'), findsNothing);
    });

    testWidgets('rechte Hälfte gibt den ganzen Stern', (tester) async {
      expect(await getippt(tester, stern: 3, linkeHaelfte: false), 4.0);
    });

    testWidgets('linke Hälfte gibt den halben', (tester) async {
      expect(await getippt(tester, stern: 3, linkeHaelfte: true), 3.5);
    });

    testWidgets('der erste Stern links ist eine halbe, nicht null',
        (tester) async {
      // Sonst gäbe es zwei Wege zu „keine Bewertung" — einen davon
      // versehentlich.
      expect(await getippt(tester, stern: 0, linkeHaelfte: true), 0.5);
    });

    testWidgets('Zurücknehmen führt zurück auf „nicht bewertet"',
        (tester) async {
      double? ergebnis = 3;
      var gerufen = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RatingInput(
            rating: 3,
            onChanged: (w) {
              ergebnis = w;
              gerufen = true;
            },
          ),
        ),
      ));
      expect(find.text('3 von 5'), findsOneWidget);

      await tester.tap(find.byTooltip('Bewertung zurücknehmen'));
      await tester.pump();

      expect(gerufen, isTrue);
      expect(ergebnis, isNull);
    });

    test('die Beschriftung spricht deutsch', () {
      expect(RatingInput.beschriftung(null), 'Noch nicht bewertet');
      expect(RatingInput.beschriftung(4), '4 von 5');
      expect(RatingInput.beschriftung(3.5), '3,5 von 5');
    });
  });

  // ------------------------------------------------------------------
  group('Was gespeichert wird', () {
    late AppDatabase db;
    late ProviderContainer container;
    late String beerId;
    late String meId;

    setUp(() async {
      db = AppDatabase.memory();
      await CommunitySync(db).importBundledData();
      beerId = (await db.select(db.beers).get()).first.id;
      meId = (await db.getMe()).id;
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => null),
      ]);
    });

    tearDown(() {
      container.dispose();
      return db.close();
    });

    test('ein Check-in ohne Bewertung bleibt ohne Bewertung', () async {
      await container.read(actionsProvider).createCheckin(beerId: beerId);
      final gespeichert = (await db.select(db.checkins).get()).single;
      expect(gespeichert.rating, isNull,
          reason: 'Genau hier stand vorher 3.5 — bei jedem Check-in.');
    });

    test('eine vergebene Bewertung wird gespeichert', () async {
      await container
          .read(actionsProvider)
          .createCheckin(beerId: beerId, rating: 4.5);
      expect((await db.select(db.checkins).get()).single.rating, 4.5);
    });

    test('eine Bewertung lässt sich wieder zurücknehmen', () async {
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: 'c-1',
            profileId: meId,
            beerId: beerId,
            rating: const Value(4),
            createdAt: DateTime(2026, 9, 3),
          ));

      // Ohne `clearRating` hieße `rating: null` „nicht anfassen" — die
      // versehentliche Bewertung bliebe für immer stehen.
      await container
          .read(actionsProvider)
          .editCheckin('c-1', clearRating: true);

      expect((await db.select(db.checkins).get()).single.rating, isNull);
    });

    test('ohne clearRating bleibt die Bewertung unangetastet', () async {
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: 'c-2',
            profileId: meId,
            beerId: beerId,
            rating: const Value(4),
            createdAt: DateTime(2026, 9, 3),
          ));

      // Eine Korrektur, die nur die Notiz ändert, darf die Bewertung
      // nicht mitlöschen.
      await container.read(actionsProvider).editCheckin('c-2', note: 'lecker');

      final zeile = (await db.select(db.checkins).get()).single;
      expect(zeile.rating, 4);
      expect(zeile.note, 'lecker');
    });
  });
}
