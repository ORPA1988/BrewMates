// Wer sieht meine Check-ins (Funktion 44, Wunsch #130).
//
// Die Regel selbst steht am Server und wird dort geprüft
// (`runden_checkins.test.sql` seit 0050, `sichtbarkeit_voreinstellung.test.sql`
// für die Vorgabe). Hier geht es um die Kette in der App: Vorbelegung,
// eigene Wahl, und dass der gewählte Wert **auch abgeschickt** wird.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/checkin/checkin_screen.dart';

import 'fake_online_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  late FakeOnlineService fake;

  setUp(() async {
    db = AppDatabase.memory();
    fake = FakeOnlineService();
    await db.into(db.breweries).insert(BreweriesCompanion.insert(
        id: 'br1', name: 'Testbrauerei', country: 'AT', city: 'Wien'));
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'b1', breweryId: 'br1', name: 'Testbier', style: 'Lager'));
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      onlineServiceProvider.overrideWith((ref) async => null),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Voreinstellung', () {
    test('Ohne Zutun ist ein Check-in für Freunde sichtbar', () async {
      await container.read(actionsProvider).createCheckin(beerId: 'b1');
      final row = (await db.select(db.checkins).get()).single;
      expect(row.visibility, SessionVisibility.friends);
    });

    test('Die Voreinstellung des Kontos greift', () async {
      await container
          .read(actionsProvider)
          .setDefaultVisibility(SessionVisibility.private);
      await container.read(actionsProvider).createCheckin(beerId: 'b1');

      final row = (await db.select(db.checkins).get()).single;
      expect(row.visibility, SessionVisibility.private);
    });

    test('Eine ausdrückliche Wahl schlägt die Voreinstellung', () async {
      await container
          .read(actionsProvider)
          .setDefaultVisibility(SessionVisibility.private);
      await container.read(actionsProvider).createCheckin(
            beerId: 'b1',
            visibility: SessionVisibility.friends,
          );

      final row = (await db.select(db.checkins).get()).single;
      expect(row.visibility, SessionVisibility.friends);
    });
  });

  group('Nachträglich ändern', () {
    test('Ein Check-in lässt sich privat stellen', () async {
      await container.read(actionsProvider).createCheckin(beerId: 'b1');
      final vorher = (await db.select(db.checkins).get()).single;
      expect(vorher.visibility, SessionVisibility.friends);

      final ok = await container.read(actionsProvider).editCheckin(
            vorher.id,
            visibility: SessionVisibility.private,
          );

      expect(ok, isTrue);
      final nachher = (await db.select(db.checkins).get()).single;
      expect(nachher.visibility, SessionVisibility.private);
    });

    test('Ohne Angabe bleibt die Sichtbarkeit, wie sie war', () async {
      await container.read(actionsProvider).createCheckin(
            beerId: 'b1',
            visibility: SessionVisibility.private,
          );
      final vorher = (await db.select(db.checkins).get()).single;

      // Nur die Bewertung ändern.
      await container
          .read(actionsProvider)
          .editCheckin(vorher.id, rating: 4.0);

      final nachher = (await db.select(db.checkins).get()).single;
      expect(nachher.visibility, SessionVisibility.private,
          reason: 'null heißt „nicht anfassen", nicht „zurücksetzen"');
    });
  });

  group('Was beim Server ankommt', () {
    test('Der gewählte Wert wird hochgeladen, nicht immer friends',
        () async {
      // Bis 0.10.19 stand in `checkins_api` fest `'visibility': 'friends'`
      // — genau dafür ist dieser Test da.
      final online = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => fake),
      ]);
      addTearDown(online.dispose);

      await online.read(actionsProvider).createCheckin(
            beerId: 'b1',
            visibility: SessionVisibility.private,
          );

      final row = (await db.select(db.checkins).get()).single;
      expect(row.visibility, SessionVisibility.private);
      expect(fake.aufrufe.where((a) => a.startsWith('insertCheckin')),
          isNotEmpty,
          reason: 'der Check-in muss überhaupt hochgeladen werden');
    });
  });

  group('Die Auswahl im Formular', () {
    Future<void> zeige(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineServiceProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
            home: CheckinScreen(preselectedBeerId: 'b1')),
      ));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      // Die Auswahl steht unter der Notiz — ohne Scrollen ist sie im
      // Test gar nicht gebaut.
      await tester.dragUntilVisible(
        find.text('Wer sieht das?'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
    }

    Future<void> abbauen(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('Alle drei Stufen stehen zur Wahl, mit Erklärung',
        (tester) async {
      await zeige(tester);

      expect(find.text('Wer sieht das?'), findsOneWidget);
      for (final v in SessionVisibility.values) {
        expect(find.text(visibilityLabel(v)), findsOneWidget);
      }
      // Die Erklärung zur Vorbelegung steht darunter.
      expect(find.text(visibilityHint(SessionVisibility.friends)),
          findsOneWidget);

      await abbauen(tester);
    });

    testWidgets('„Nur meine Crew" sagt, dass es ohne Runde nichts tut',
        (tester) async {
      await zeige(tester);
      await tester.tap(find.text('Nur meine Crew'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ohne Runde'), findsOneWidget);
      await abbauen(tester);
    });
  });
}
