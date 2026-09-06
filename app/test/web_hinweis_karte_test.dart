// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/home/home_screen.dart';

import 'fake_browserfenster.dart';
import 'fake_online_service.dart';

/// Der Browser-Hinweis auf der Startseite (Funktion 38).
///
/// Die Verzweigung selbst steht in `web_hinweis_test.dart`. Hier geht es
/// um die zweite Bedingung, die nur der Bildschirm kennt: **angemeldet**.
/// Unangemeldet gibt es weder Anfragen noch Beacons — ein Hinweis auf
/// Meldungen wäre dort ein Versprechen ohne Inhalt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;
  late FakesFenster fenster;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
    fenster = FakesFenster();
  });

  tearDown(() => fenster.dispose());

  Widget umgebung({required bool angemeldet}) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineServiceProvider.overrideWith((ref) async => online),
          browserfensterProvider.overrideWithValue(fenster),
          onlineUserProvider.overrideWith((ref) => Stream.value(angemeldet
              ? User(
                  id: '11111111-1111-1111-1111-111111111111',
                  appMetadata: const {},
                  userMetadata: const {},
                  aud: 'authenticated',
                  createdAt: DateTime(2026).toIso8601String(),
                )
              : null)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      );

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Angemeldet im Browser: der Hinweis auf den Erlaubnis-Knopf',
      (tester) async {
    await tester.pumpWidget(umgebung(angemeldet: true));
    await tester.pumpAndSettle();

    expect(find.text('Meldungen im Browser einschalten'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Unangemeldet schweigt die Startseite', (tester) async {
    await tester.pumpWidget(umgebung(angemeldet: false));
    await tester.pumpAndSettle();

    expect(find.text('Meldungen im Browser einschalten'), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Wegwischen merkt sich der Browser', (tester) async {
    await tester.pumpWidget(umgebung(angemeldet: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nicht mehr zeigen'));
    await tester.pumpAndSettle();

    expect(find.text('Meldungen im Browser einschalten'), findsNothing);
    // Nicht nur ausgeblendet: Der Stand liegt im Browser und überlebt
    // damit das Neuladen — sonst käme der Hinweis bei jedem Öffnen wieder.
    expect(fenster.weggewischt, contains(WebHinweis.erlauben.name));
    await abbauen(tester);
  });

  testWidgets('Ohne Notification führt der Hinweis zur Anleitung',
      (tester) async {
    // Der iPhone-Fall: Safari stellt `Notification` außerhalb einer
    // installierten Web-App nicht bereit.
    fenster.erlaubnis = Browserfenster.nichtVerfuegbar;

    await tester.pumpWidget(umgebung(angemeldet: true));
    await tester.pumpAndSettle();

    expect(find.text('BrewMates auf den Home-Bildschirm'), findsOneWidget);

    await tester.tap(find.text('BrewMates auf den Home-Bildschirm'));
    await tester.pumpAndSettle();

    expect(find.text('Zum Home-Bildschirm hinzufügen'), findsOneWidget);
    expect(find.textContaining('Teilen-Symbol'), findsOneWidget);
    await tester.tap(find.text('Verstanden'));
    await tester.pumpAndSettle();
    await abbauen(tester);
  });
}
