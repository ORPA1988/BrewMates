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
import 'package:brewmates/features/profile/profile_screen.dart';
import 'package:brewmates/features/profile/widgets/schnellzugriff.dart';

/// Die Profil-Übersicht (Funktion 47).
///
/// **Was hier wirklich geprüft wird: die Reihenfolge.** Der Umbau hat
/// keine Funktion hinzugefügt — Freunde, Tagebuch, Statistik und
/// Challenges waren alle schon erreichbar. Er hat sie nur dorthin
/// gestellt, wo man sie findet, und den neun Zahlen eine Auskunft
/// gegeben. Genau das ist deshalb prüfbar zu halten: Ein späterer Anbau,
/// der den Schnellzugriff wieder unter die Heatmap schiebt, soll auffallen.
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

  /// Legt [anzahl] Check-ins an, je einen Tag auseinander.
  Future<void> seed(int anzahl) async {
    for (var t = 0; t < anzahl; t++) {
      await db.into(db.checkins).insert(CheckinsCompanion.insert(
            id: 'c$t',
            profileId: myId,
            beerId: beers[t % beers.length].id,
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
          home: const ProfileScreen(),
        ),
      );

  /// **Telefonformat, nicht die Standard-Testgröße.** Auf 800×600 nimmt
  /// das Zahlenraster vier Spalten statt zwei, und was unten steht, liegt
  /// woanders — der Test prüfte dann ein Layout, das niemand benutzt.
  Future<void> oeffnen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  /// Zieht die Liste weiter, weil `ListView` nur baut, was sichtbar ist:
  /// Ein `findsNothing` weiter unten wäre sonst wertlos.
  Future<void> weiter(WidgetTester tester, {int mal = 6}) async {
    for (var i = 0; i < mal; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Der Schnellzugriff steht über den Zahlen', (tester) async {
    await seed(5);
    await oeffnen(tester);

    // Die eigentliche Aussage des Umbaus: Die vier Wege stehen oben, die
    // Zahlen darunter. Vorher lagen Freunde, Tagebuch und Statistik als
    // Listeneinträge unter allem.
    expect(find.byType(Schnellzugriff), findsOneWidget);
    final zugriff = tester.getTopLeft(find.byType(Schnellzugriff)).dy;
    final zahlen = tester.getTopLeft(find.text('Deine Zahlen')).dy;
    expect(zugriff, lessThan(zahlen),
        reason: 'Die Zahlen stehen wieder über den Wegen');

    for (final titel in ['Challenges', 'Freunde', 'Tagebuch', 'Statistik']) {
      expect(find.text(titel), findsOneWidget, reason: '$titel fehlt');
    }

    await abbauen(tester);
  });

  testWidgets('Jede Kachel sagt einen Stand, nicht nur ihren Namen',
      (tester) async {
    await seed(3);
    await oeffnen(tester);

    // Ohne Konto gibt es keine Freundesliste — die Kachel sagt das,
    // statt eine Null zu behaupten.
    expect(find.text('Anmelden für echte Freunde'), findsOneWidget);
    expect(find.text('3 Check-ins'), findsOneWidget);
    expect(find.textContaining('zuletzt'), findsOneWidget);
    // Ohne geladene Challenges: der ehrliche Satz statt einer Lücke.
    expect(find.text('Gerade läuft keine'), findsOneWidget);

    await abbauen(tester);
  });

  testWidgets('Ohne Check-ins sagt das Tagebuch das, statt zu schweigen',
      (tester) async {
    await oeffnen(tester);

    expect(find.text('Noch kein Check-in'), findsOneWidget);

    await abbauen(tester);
  });

  testWidgets('Eine Zahlen-Kachel öffnet ihre Aufschlüsselung',
      (tester) async {
    await seed(6);
    await oeffnen(tester);

    await tester.tap(find.text('Stile'));
    await tester.pumpAndSettle();

    // Das Blatt erklärt die Zahl und zerlegt sie — beides, nicht eins
    // von beidem: Die Aufschlüsselung sagt „woraus", der Satz „was".
    expect(find.text('Deine Bierstile'), findsOneWidget);
    expect(find.textContaining('Wie breit du unterwegs bist'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.text('Zur vollen Statistik'), findsOneWidget);

    await abbauen(tester);
  });

  testWidgets('Auch eine Zahl ohne Aufteilung erklärt sich', (tester) async {
    await seed(2);
    await oeffnen(tester);

    // „Sessions" hat keine Aufschlüsselung. Es wäre der bequeme Weg,
    // solche Kacheln stumm zu lassen — dann reagierten sechs von neun,
    // und das sähe aus wie ein Fehler.
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Deine Runden'), findsOneWidget);
    expect(find.textContaining('als Gastgeber oder als Gast'), findsOneWidget);
    // Kein Balken, kein Knopf — und trotzdem eine Auskunft.
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await abbauen(tester);
  });

  testWidgets('Ohne Check-ins zeigt das Blatt den nächsten Schritt',
      (tester) async {
    await oeffnen(tester);

    await tester.tap(find.text('Stile'));
    await tester.pumpAndSettle();

    // Kein leerer Kasten: Wer noch nichts eingetragen hat, braucht den
    // nächsten Schritt, nicht die Feststellung, dass nichts da ist.
    expect(find.textContaining('dein erster wartet'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await abbauen(tester);
  });

  testWidgets('Was selten gebraucht wird, steht weiter unten — aber da',
      (tester) async {
    await seed(2);
    await oeffnen(tester);
    await weiter(tester);

    for (final eintrag in ['Konto', 'Wunschliste', 'Dein Bierjahr']) {
      expect(find.text(eintrag), findsOneWidget,
          reason: '$eintrag ist beim Umbau verloren gegangen');
    }

    await abbauen(tester);
  });
}
