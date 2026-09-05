// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
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
import 'package:brewmates/features/stats/stats_screen.dart';

/// Der Statistik-Bildschirm mit echten Daten.
///
/// Bis 0.10.13 hatte er **keinen** Widget-Test — geprüft war nur die
/// Rechnung darunter (`statistics_test.dart`). Das ging, solange der
/// Bildschirm vier feste Balkenblöcke zeigte. Seit die Aufteilung per
/// Chip gewählt wird, ist die Verbindung zwischen Auswahl und Anzeige
/// selbst eine Behauptung, die jemand prüfen muss.
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

  /// Legt Check-ins an — [tage] Tage vor dem Stichtag, je einer.
  Future<void> seed(List<int> tage, {String? sessionId}) async {
    for (final t in tage) {
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: 'c$t-${sessionId ?? ''}',
            profileId: myId,
            beerId: beers[t % beers.length].id,
            sessionId: Value(sessionId),
            rating: const Value(4),
            createdAt: DateTime(2026, 8, 15).subtract(Duration(days: t)),
          ));
    }
  }

  Widget app() => ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) => db),
          // Kein Supabase in Widget-Tests: der Offline-Pfad ist der
          // Testpfad.
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
          home: const StatsScreen(),
        ),
      );

  /// Wartet die Drift-Ströme ab und baut danach sauber ab.
  ///
  /// **Telefonformat, nicht die Standard-Testgröße.** Auf 800×600 liegen
  /// die Chips außerhalb der Fläche: Ein Tipp darauf geht ins Leere, und
  /// der Test meldet einen Fehler, den es in der App nicht gibt.
  Future<void> oeffnen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  /// Zieht die Liste ans Ende.
  ///
  /// Nötig, weil `ListView` nur baut, was sichtbar ist: Ein `find.text`
  /// auf etwas weiter unten findet nichts — und ein `findsNothing` wäre
  /// dort wertlos, weil es auch bei vorhandenem Inhalt zutrifft.
  Future<void> ansEnde(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Ohne Check-ins steht da, was fehlt — keine Nullen',
      (tester) async {
    await oeffnen(tester);

    expect(find.textContaining('dein erster Check-in fehlt'), findsOneWidget);
    // Keine Kacheln mit 0: Eine Auswertung ohne Daten ist keine
    // Auswertung mit Nullwerten.
    expect(find.text('Check-ins'), findsNothing);

    await abbauen(tester);
  });

  testWidgets('Die Kennzahlen erscheinen als Kacheln', (tester) async {
    await seed([1, 2, 3]);
    await oeffnen(tester);

    expect(find.text('Check-ins'), findsOneWidget);
    expect(find.text('verschiedene Biere'), findsOneWidget);
    expect(find.text('Ø Bewertung'), findsOneWidget);
    // Ohne Ort keine Ortskachel — die Kennzahl blendet sich selbst aus.
    expect(find.text('Orte'), findsNothing);

    await abbauen(tester);
  });

  testWidgets('Der Chip wechselt die Aufteilung', (tester) async {
    await seed([1, 2, 3]);
    await oeffnen(tester);

    // „Stil" ist die erste Aufteilung und steht offen.
    expect(find.widgetWithText(ChoiceChip, 'Stil'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Wochentag'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Wochentag'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Wochentag'));
    await tester.pumpAndSettle();

    // Die Überschrift der Balkenreihe folgt der Auswahl. Ein Wochentag
    // taucht auf, der vorher nicht dastand.
    expect(find.text('Wochentag'), findsNWidgets(2)); // Chip + Überschrift
    expect(
      find.byWidgetPredicate((w) =>
          w is Text &&
          const [
            'Montag',
            'Dienstag',
            'Mittwoch',
            'Donnerstag',
            'Freitag',
            'Samstag',
            'Sonntag',
          ].contains(w.data)),
      findsWidgets,
    );

    await abbauen(tester);
  });

  testWidgets('Die Alkoholzahl steht unten und nennt ihre Lücken',
      (tester) async {
    // Vom Menschen entschieden (Regel K): anzeigen, sachlich, mit
    // ausgewiesenem Schätzanteil — nie als Vergleich oder Warnung.
    final mitAbv = beers.firstWhere((b) => b.abv != null);
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'alk1',
          profileId: myId,
          beerId: mitAbv.id,
          createdAt: DateTime(2026, 8, 14),
        ));
    await oeffnen(tester);
    await ansEnde(tester);

    expect(find.text('Reinalkohol im Zeitraum'), findsOneWidget);
    // Die Füllmenge fehlt an diesem Check-in — das muss dastehen.
    expect(find.textContaining('geschätzt'), findsWidgets);
    // Kein Vergleich, keine Einordnung, keine Warnung.
    expect(find.textContaining('zu viel'), findsNothing);
    expect(find.textContaining('Standardgl'), findsNothing);

    await abbauen(tester);
  });

  testWidgets('Ohne hinterlegten Alkoholgehalt fehlt die Karte ganz',
      (tester) async {
    final ohneAbv = beers.where((b) => b.abv == null).toList();
    if (ohneAbv.isEmpty) {
      // Der gebündelte Bestand hat überall einen Wert — dann ist dieser
      // Fall in der App nicht erreichbar und der Test hat nichts zu
      // prüfen.
      return;
    }
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'ohne1',
          profileId: myId,
          beerId: ohneAbv.first.id,
          createdAt: DateTime(2026, 8, 14),
        ));
    await oeffnen(tester);
    await ansEnde(tester);

    expect(find.text('Reinalkohol im Zeitraum'), findsNothing);
    // Die Liste ist wirklich am Ende — sonst prüfte der Satz oben nichts.
    // (Der Fußtext heißt seit 0.10.16 anders: Er sagt jetzt, was der
    // Vergleich mit anderen ist und was nicht, siehe Funktion 42.)
    expect(find.textContaining('keine Rangliste'), findsOneWidget);

    await abbauen(tester);
  });

  testWidgets('Der Bildschirm ist bedienbar und lesbar', (tester) async {
    // Dieselben drei Prüfungen wie in `barrierefreiheit_test.dart` — hier
    // gleich mit, weil dieser Bildschirm die meisten Chips der App hat
    // und ein zu kleines Tap-Ziel dort zuerst entstünde.
    await seed([1, 2, 3]);
    final semantik = tester.ensureSemantics();
    await oeffnen(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    semantik.dispose();
    await abbauen(tester);
  });
}
