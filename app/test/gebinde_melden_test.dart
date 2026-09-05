// Fehlende Gebindegröße im Scan-Treffer (Funktion 43).
//
// Baut seine Daten mit `AppDatabase.memory()` auf — die gibt es nur auf
// der VM (siehe `scan_screen_test.dart`).
@TestOn('vm')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/scan/scan_screen.dart';

import 'fake_online_service.dart';

/// Aus der gebündelten Datenbank: eine EAN ohne und eine mit Größe.
const _ohneGroesse = '90147159';       // Baumgartner Märzen
const _mitGroesse = '9014700000704';   // Baumgartner Weisse, 0,5 l

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService fake;

  setUp(() async {
    db = AppDatabase.memory();
    fake = FakeOnlineService();
    await CommunitySync(db).importBundledData();
  });

  Future<void> scanne(WidgetTester tester, String ean) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => fake),
      ],
      child: const MaterialApp(home: ScanScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), ean);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('Fehlt die Größe, steht sie rot da — nicht gar nicht',
      (tester) async {
    await scanne(tester, _ohneGroesse);

    expect(find.text('Gefunden! 🎯'), findsOneWidget);
    final hinweis = find.textContaining('Gebindegröße fehlt');
    expect(hinweis, findsOneWidget);

    // Rot heißt: **die Fehlerfarbe des Themes**, kein fest verdrahteter
    // Rotton — sonst stimmt sie im dunklen Modus nicht mehr.
    final text = tester.widget<Text>(hinweis);
    final theme = Theme.of(tester.element(hinweis));
    expect(text.style?.color, theme.colorScheme.error);

    // Und daneben steht ein Stift: Farbe allein sagt nicht, dass man
    // etwas tun kann — und wer Rot nicht unterscheidet, sähe sonst nur
    // einen Satz (docs/14).
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await abbauen(tester);
  });

  testWidgets('Ist die Größe bekannt, steht sie schlicht da',
      (tester) async {
    await scanne(tester, _mitGroesse);

    expect(find.text('Gefunden! 🎯'), findsOneWidget);
    expect(find.textContaining('Gebindegröße fehlt'), findsNothing);
    expect(find.text('0,5 l'), findsOneWidget);

    await abbauen(tester);
  });

  testWidgets('Ein Tipp bietet die Größen an', (tester) async {
    await scanne(tester, _ohneGroesse);

    await tester.tap(find.textContaining('Gebindegröße fehlt'));
    await tester.pumpAndSettle();

    expect(find.text('Wie groß ist dieses Gebinde?'), findsOneWidget);
    // Dieselben Größen wie im Check-in, und der Hinweis zum Tragerl.
    expect(find.text('0,33 l'), findsOneWidget);
    expect(find.textContaining('Tragerl'), findsOneWidget);

    await abbauen(tester);
  });

  testWidgets('Ohne Konto wird nichts geschrieben, sondern gesagt warum',
      (tester) async {
    fake.abgemeldet = true;
    await scanne(tester, _ohneGroesse);

    await tester.tap(find.textContaining('Gebindegröße fehlt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0,5 l'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.textContaining('angemeldet sein'), findsOneWidget);
    expect(await db.barcodeVolume(_ohneGroesse), isNull);

    await abbauen(tester);
  });
}
