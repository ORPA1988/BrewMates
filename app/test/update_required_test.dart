// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/main.dart';
import 'package:brewmates/widgets/update_required_screen.dart';

/// Der Riegel „Update erforderlich" im Zusammenspiel mit der App.
///
/// Die gefährliche Richtung ist **nicht**, dass er zu selten greift,
/// sondern dass er zu oft greift: Sperrt er bei einem Netzproblem, ist
/// eine App unbenutzbar, die ohne Netz vollständig funktioniert. Deshalb
/// prüfen hier drei von vier Tests, dass er **nicht** anspringt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
  });

  Future<void> zeige(WidgetTester tester,
      {required AsyncValue<bool> antwort}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => null),
        updatePflichtProvider.overrideWith((ref) => antwort.when(
              data: (v) async => v,
              error: (e, _) => Future<bool>.error(e),
              // Nie abschliessend: genau der Zustand „Antwort steht aus".
              loading: () => Completer<bool>().future,
            )),
      ],
      child: const BrewMatesApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Sagt der Server „zu alt", erscheint der Sperrbildschirm',
      (tester) async {
    await zeige(tester, antwort: const AsyncValue.data(true));

    expect(find.byType(UpdateRequiredScreen), findsOneWidget);
    // Die Meldung muss den Grund nennen, nicht nur ein Problem behaupten.
    expect(find.textContaining('nicht mehr unterstützt'), findsOneWidget);
    // Und die Sorge nehmen, die jeder zuerst hat.
    expect(find.textContaining('bleiben erhalten'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Sagt der Server „passt", läuft die App normal', (tester) async {
    await zeige(tester, antwort: const AsyncValue.data(false));
    expect(find.byType(UpdateRequiredScreen), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Während die Antwort aussteht, sperrt nichts', (tester) async {
    await zeige(tester, antwort: const AsyncValue.loading());
    expect(find.byType(UpdateRequiredScreen), findsNothing,
        reason: 'Sonst blitzte der Sperrbildschirm bei jedem Start kurz '
            'auf — und bei langsamer Verbindung bliebe er stehen.');
    await abbauen(tester);
  });

  testWidgets('Scheitert die Abfrage, sperrt nichts', (tester) async {
    await zeige(tester,
        antwort: AsyncValue.error(Exception('offline'), StackTrace.empty));
    expect(find.byType(UpdateRequiredScreen), findsNothing,
        reason: 'BrewMates funktioniert ohne Netz vollständig. Ein '
            'Funkloch darf niemanden aussperren.');
    await abbauen(tester);
  });
}
