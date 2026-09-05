// Vergleich mit den anderen BrewMates (Wunsch #146).
//
// Die Regel, auf die es ankommt, liegt am Server (Migration 0054, dazu
// `supabase/tests/community_vergleich.test.sql`): Unter genug
// beitragenden Personen gibt es keine Durchschnitte. Hier wird geprüft,
// dass die App das ehrlich wiedergibt statt eine Zahl zu erfinden.
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/stats/stats_screen.dart';

import 'fake_online_service.dart';

void main() {
  late AppDatabase db;
  late FakeOnlineService fake;

  setUp(() async {
    db = AppDatabase.memory();
    fake = FakeOnlineService();
    await db.into(db.breweries).insert(BreweriesCompanion.insert(
        id: 'br1', name: 'Testbrauerei', country: 'AT', city: 'Wien'));
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'b1', breweryId: 'br1', name: 'Testbier', style: 'Lager'));
    final me = await db.getMe();
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'c1',
          profileId: me.id,
          beerId: 'b1',
          rating: const Value(4.0),
          createdAt: DateTime.now(),
        ));
  });

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => fake),
      ],
      child: const MaterialApp(home: StatsScreen()),
    ));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Zu wenige andere: die App sagt es, statt zu rechnen',
      (tester) async {
    fake.communityStats = (teilnehmer: 3, checkins: null, biere: null);
    await zeige(tester);

    expect(find.textContaining('noch zu wenige'), findsOneWidget);
    expect(find.textContaining('3 andere'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Mit genug anderen steht der Schnitt da', (tester) async {
    fake.communityStats = (teilnehmer: 42, checkins: 7.3, biere: 5.0);
    await zeige(tester);

    expect(find.textContaining('im Schnitt'), findsOneWidget);
    expect(find.textContaining('7,3'), findsNothing); // Punkt, nicht Komma
    expect(find.textContaining('7.3'), findsOneWidget);
    // Ganze Zahl ohne Nachkomma: „5", nicht „5.0".
    expect(find.textContaining('5 verschiedene Biere'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Ohne Vergleich fehlt die Karte ganz statt leer zu stehen',
      (tester) async {
    fake.communityStats = null;
    await zeige(tester);

    expect(find.text('Im Vergleich'), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Es gibt keine Rangliste und keine Namen', (tester) async {
    fake.communityStats = (teilnehmer: 42, checkins: 7.3, biere: 5.0);
    await zeige(tester);

    // Der Fußtext hält fest, was der Vergleich nicht ist. Er steht ganz
    // unten — ohne Scrollen ist er nicht gebaut.
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.textContaining('keine Rangliste'), findsOneWidget);
    await abbauen(tester);
  });
}
