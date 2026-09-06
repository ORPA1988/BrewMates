// Baut die Daten mit `AppDatabase.memory()` auf — die gibt es nur auf
// der VM (docs/features/18-plattformen.md).
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/theme.dart';
import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/rueckblick/rueckblick_screen.dart';

/// #167 — Dein Bierjahr auf einer Seite.
///
/// Die Rechnung prüft `jahresrueckblick_test.dart`. Hier geht es um
/// zwei Behauptungen des Bildschirms: Er zeigt die Zahlen des gewählten
/// Jahres, und er sagt vorher, was auf dem Bild landet.
void main() {
  late AppDatabase db;
  late String myId;
  late List<Beer> beers;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    myId = (await db.getMe()).id;
    beers = await db.select(db.beers).get();
  });

  tearDown(() => db.close());

  Future<void> seed(List<DateTime> wann) async {
    for (var i = 0; i < wann.length; i++) {
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: 'c$i',
            profileId: myId,
            beerId: beers[i % beers.length].id,
            rating: const Value(4),
            createdAt: wann[i],
          ));
    }
  }

  Widget app() => ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) => db),
          onlineServiceProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: BrewTheme.light,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          home: const RueckblickScreen(),
        ),
      );

  Future<void> oeffnen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Ohne Check-ins bleibt der Rückblick leer — und sagt es',
      (tester) async {
    await oeffnen(tester);
    expect(find.textContaining('gibt es noch nichts zurückzublicken'),
        findsOneWidget);
    // Kein Knopf, der ein leeres Bild erzeugt.
    expect(find.text('Als Bild speichern'), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Mit Check-ins stehen die Zahlen des Jahres da',
      (tester) async {
    final jahr = DateTime.now().year;
    await seed([
      DateTime(jahr, 3, 2, 20),
      DateTime(jahr, 3, 9, 20),
      DateTime(jahr, 7, 1, 20),
    ]);
    await oeffnen(tester);

    expect(find.text('Mein Bierjahr $jahr'), findsOneWidget);
    // Die Zeilen sind RichText (fette Zahl, normale Beschriftung) —
    // `find.text` sieht dort ohne `findRichText` nichts.
    expect(
      find.textContaining('3  Check-ins', findRichText: true),
      findsOneWidget,
    );
    // Der Knopf steht unter der Fläche und ist deshalb erst nach dem
    // Ziehen gebaut — ein `findsOneWidget` ohne das wäre wertlos.
    await tester.dragUntilVisible(
      find.text('Als Bild speichern'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Als Bild speichern'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Der Hinweis sagt vorher, was auf dem Bild landet',
      (tester) async {
    // Ein Bild, das man weitergibt, ohne zu wissen, was drauf ist, wäre
    // genau die Art Überraschung, die eine App sich nicht leisten darf.
    await seed([DateTime(DateTime.now().year, 5, 5, 18)]);
    await oeffnen(tester);
    // Der Hinweis steht unter dem Knopf und damit außerhalb der Fläche.
    await tester.dragUntilVisible(
      find.textContaining('keinen Namen'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('keinen Namen'), findsOneWidget);
    await abbauen(tester);
  });
}
