import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/models.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/crews/crews_screen.dart';

import 'fake_online_service.dart';

/// Freunde in eine Crew einladen (Migration 0044).
///
/// **Die Entscheidung, die hier geprüft wird:** Eine Einladung braucht
/// eine Antwort, der Einladungscode nicht. Das sieht wie ein Widerspruch
/// aus und ist keiner — beim Code entscheidet der Eingeladene selbst, er
/// tippt ihn ein. Bei einer Einladung entscheidet ein anderer, und in
/// eine Crew zu kommen ändert, wer den eigenen Aufenthaltsort während
/// einer Crew-Runde sieht.
///
/// Die Regeln dazu stehen am Server (`supabase/tests/crew_invites.test.sql`,
/// 14 Prüfungen in der Rolle `authenticated`). Hier geht es um das, was
/// der Mensch sieht.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  CrewInvite einladung({String crewId = 'crew-1'}) => CrewInvite(
        crewId: crewId,
        crewName: 'Stammtisch',
        crewEmoji: '👥',
        inviter: const RemoteProfile(
          id: 'p1',
          username: 'anna',
          displayName: 'Anna',
          avatarEmoji: '🍺',
        ),
        createdAt: DateTime(2026, 9, 3),
      );

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
  });

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
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
          initialLocation: '/crews',
          routes: [
            GoRoute(
              path: '/crews',
              builder: (_, __) => const CrewsScreen(),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Eine Einladung verdeckt den leeren Zustand nicht',
      (tester) async {
    // Wer noch keine Crew hat, aber eingeladen wurde, sähe sonst „Noch
    // keine Crew" — und die Einladung gar nicht.
    online.einladungen = [einladung()];
    await zeige(tester);

    expect(find.textContaining('Noch keine Crew'), findsNothing);
    expect(find.text('Stammtisch'), findsOneWidget);
    expect(find.textContaining('Anna lädt dich ein'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Sie sagt, was der Beitritt bedeutet', (tester) async {
    // Nicht im Kleingedruckten: Wer zusagt, zeigt der Crew künftig seinen
    // Standort während eines Crew-Beacons.
    online.einladungen = [einladung()];
    await zeige(tester);

    expect(find.textContaining('Standort'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Beitreten trägt ein und räumt die Einladung weg',
      (tester) async {
    online.einladungen = [einladung()];
    await zeige(tester);

    await tester.tap(find.text('Beitreten'));
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('acceptInvite:crew-1'));
    expect(online.angenommen, ['crew-1']);
    expect(find.textContaining('Willkommen in der Crew'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Ablehnen tritt niemandem bei', (tester) async {
    online.einladungen = [einladung()];
    await zeige(tester);

    await tester.tap(find.text('Ablehnen'));
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('declineInvite:crew-1:ich'));
    expect(online.angenommen, isEmpty);
    expect(find.textContaining('abgelehnt'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Scheitert der Server, bleibt die Einladung stehen',
      (tester) async {
    // Regel A-8: kein Erfolg, den der Server nicht bestätigt hat. Wer
    // glaubt, beigetreten zu sein, wundert sich sonst, warum er die Crew
    // nicht sieht.
    online
      ..einladungen = [einladung()]
      ..schlaegtFehl = true;
    await zeige(tester);

    await tester.tap(find.text('Beitreten'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hat nicht geklappt'), findsOneWidget);
    expect(find.textContaining('Willkommen'), findsNothing);
    expect(online.angenommen, isEmpty);
    await abbauen(tester);
  });

  testWidgets('Ohne Einladung bleibt der leere Zustand', (tester) async {
    await zeige(tester);
    expect(find.textContaining('Noch keine Crew'), findsOneWidget);
    await abbauen(tester);
  });
}
