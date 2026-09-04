// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/brewmates_code.dart';
import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/crews/crew_scan_screen.dart';

import 'fake_online_service.dart';

/// Crew-Beitritt per QR (Roadmap-Punkt „Crews per QR-Code", Issue #62).
///
/// Die Kamera lässt sich im Test nicht betreiben — sie liefert am Ende
/// aber nur eine Zeichenkette an `_handleCode`, und genau dort sitzt
/// alles, was schiefgehen kann. `handleCodeForTest` ist derselbe
/// Einstieg, den der Freundes-Scanner aus demselben Grund schon hat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  const crewId = '3f2a91c4-5b6d-4e7f-8a90-1b2c3d4e5f60';

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
  });

  Future<_CrewScanScreenHandle> zeige(WidgetTester tester) async {
    // Ohne Kamera-Plattform baut der Bildschirm den Scanner nicht — der
    // Weg dahinter ist derselbe.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => online),
      ],
      child: const MaterialApp(home: CrewScanScreen()),
    ));
    await tester.pumpAndSettle();
    return _CrewScanScreenHandle(tester);
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('Ein Crew-Code lässt beitreten', (tester) async {
    final screen = await zeige(tester);
    await screen.scanne(buildCrewCode(crewId));

    expect(online.aufrufe, contains('joinCrew:$crewId'));
    expect(online.beigetreteneCrews, [crewId]);
    expect(find.text('Du bist dabei!'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Ein Freundes-Code sagt, wo er hingehört', (tester) async {
    // Der neue Fehlerfall, den es vor den Crew-Codes nicht gab: der
    // richtige Code am falschen Scanner. „Kein BrewMates-Code" wäre
    // hier gelogen.
    final screen = await zeige(tester);
    await screen.scanne(buildFriendCode(crewId));

    expect(online.aufrufe.where((a) => a.startsWith('joinCrew')), isEmpty);
    expect(find.textContaining('Freunde'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Ein fremder QR-Code wird nicht als Einladung gelesen',
      (tester) async {
    final screen = await zeige(tester);
    await screen.scanne('WIFI:S=Gasthaus;T=WPA;P=bier;;');

    expect(online.aufrufe.where((a) => a.startsWith('joinCrew')), isEmpty);
    expect(find.text('Das ist kein BrewMates-Code.'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Ein unbekannter Code beendet den Scanner nicht',
      (tester) async {
    // Nach einem Fehlschlag steht der nächste Versuch an — den Scanner
    // dann abzuschalten wäre die falsche Antwort.
    online.schlaegtFehl = true;
    final screen = await zeige(tester);
    await screen.scanne(buildCrewCode(crewId));

    expect(find.textContaining('Einladungscode gibt es nicht'),
        findsOneWidget);
    expect(find.text('Du bist dabei!'), findsNothing);

    online.schlaegtFehl = false;
    await screen.scanne(buildCrewCode(crewId));
    expect(find.text('Du bist dabei!'), findsOneWidget,
        reason: 'Der zweite Versuch muss durchkommen.');
    await abbauen(tester);
  });
}

/// Kleiner Griff auf den Bildschirm — spart in jedem Test drei Zeilen.
class _CrewScanScreenHandle {
  _CrewScanScreenHandle(this.tester);

  final WidgetTester tester;

  Future<void> scanne(String code) async {
    final state = tester.state<ConsumerState<CrewScanScreen>>(
        find.byType(CrewScanScreen)) as dynamic;
    await state.handleCodeForTest(code);
    await tester.pumpAndSettle();
  }
}
