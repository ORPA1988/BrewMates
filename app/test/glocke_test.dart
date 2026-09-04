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
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/shell/app_shell.dart';

import 'fake_online_service.dart';

/// Die Glocke (0031): Eine Benachrichtigung, die live ankommt, muss sich
/// **melden** — auf jedem Tab — und die Listen dahinter aktualisieren.
///
/// Bis hierher gab es keinen Benachrichtigungsweg; der andere erfuhr von
/// einer Anfrage nur, wenn er die App oeffnete und der 30-Sekunden-Takt
/// zufaellig lief.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  const clara = RemoteProfile(
    id: '22222222-2222-2222-2222-222222222222',
    username: 'clara',
    displayName: 'Clara',
    avatarEmoji: '🍺',
  );

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
  });

  Widget umgebung() => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineServiceProvider.overrideWith((ref) async => online),
          onlineUserProvider.overrideWith((ref) => Stream.value(User(
                id: '11111111-1111-1111-1111-111111111111',
                appMetadata: const {},
                userMetadata: const {},
                aud: 'authenticated',
                createdAt: DateTime(2026).toIso8601String(),
              ))),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/karte',
            routes: [
              StatefulShellRoute.indexedStack(
                builder: (_, __, shell) => AppShell(shell: shell),
                branches: [
                  for (final pfad in ['/home', '/feed', '/karte', '/beers', '/profil'])
                    StatefulShellBranch(routes: [
                      GoRoute(
                        path: pfad,
                        builder: (_, __) => Scaffold(body: Text('Seite $pfad')),
                      ),
                    ]),
                ],
              ),
              GoRoute(
                path: '/friends',
                builder: (_, __) => const Scaffold(body: Text('Freunde-Seite')),
              ),
            ],
          ),
        ),
      );

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Eine eintreffende Anfrage meldet sich auf jedem Tab',
      (tester) async {
    await tester.pumpWidget(umgebung());
    await tester.pumpAndSettle();
    // Wir stehen auf der Karte, nicht auf der Startseite.
    expect(find.text('Seite /karte'), findsOneWidget);

    final vorher =
        online.aufrufe.where((a) => a == 'incomingRequests').length;

    online.eingehend.add(RemoteNotification(
      id: 'n1',
      type: 'friend_request',
      createdAt: DateTime(2026, 8, 16),
      actor: clara,
    ));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Clara moechte dein BrewMate sein'),
        findsOneWidget);
    expect(find.text('Ansehen'), findsOneWidget);

    // Und die Liste dahinter wurde neu geladen — sonst zeigt „Ansehen"
    // einen alten Stand.
    final nachher =
        online.aufrufe.where((a) => a == 'incomingRequests').length;
    expect(nachher, greaterThan(vorher),
        reason: 'Die Anfrageliste muss nach dem Ereignis neu geladen sein.');

    await tester.tap(find.text('Ansehen'));
    await tester.pumpAndSettle();
    expect(find.text('Freunde-Seite'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Eine Annahme meldet sich ohne „Ansehen"', (tester) async {
    await tester.pumpWidget(umgebung());
    await tester.pumpAndSettle();

    online.eingehend.add(RemoteNotification(
      id: 'n2',
      type: 'friend_accepted',
      createdAt: DateTime(2026, 8, 16),
      actor: clara,
    ));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Clara hat deine Anfrage angenommen'),
        findsOneWidget);
    expect(find.text('Ansehen'), findsNothing);
    await abbauen(tester);
  });
}
