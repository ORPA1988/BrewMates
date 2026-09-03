import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/models.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/widgets/glocke.dart';

import 'fake_online_service.dart';

/// Die Nachlese zu allem, was geweckt hat.
///
/// **Die Lücke, die das schließt:** `notifications` füllt sich seit 0031,
/// der Push weckt seit 0039 das Gerät, im Browser meldet sich seit
/// 0.10.11 der Tab — aber wer die Meldung verpasste, fand sie nirgends
/// wieder. `unreadNotificationsProvider` holte den Bestand seit jeher,
/// und keine einzige Stelle zeigte ihn an. Ein Weckruf ohne Nachlese ist
/// eine halbe Funktion: Man weiß, dass etwas war, und nicht was.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  RemoteNotification meldung(String id, String typ, {String? subject}) =>
      RemoteNotification(
        id: id,
        type: typ,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        subjectType: subject == null ? null : 'session',
        subjectId: subject,
        actor: const RemoteProfile(
          id: 'p1',
          username: 'anna',
          displayName: 'Anna',
          avatarEmoji: '🍺',
        ),
      );

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
  });

  Future<void> zeige(WidgetTester tester, {bool angemeldet = true}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => online),
        onlineUserProvider.overrideWith((ref) =>
            Stream.value(angemeldet
                ? User(
                    id: '11111111-1111-1111-1111-111111111111',
                    appMetadata: const {},
                    userMetadata: const {},
                    aud: 'authenticated',
                    createdAt: DateTime(2026).toIso8601String(),
                  )
                : null)),
      ],
      // Mit echtem Router: Ein Tipp auf eine Meldung springt irgendwohin,
      // und das gehört zum geprüften Verhalten.
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Glocke()),
            ),
            GoRoute(
              path: '/friends',
              builder: (_, __) => const Scaffold(body: Text('Freunde')),
            ),
            GoRoute(
              path: '/session/:id',
              builder: (_, state) =>
                  Scaffold(body: Text('Runde ${state.pathParameters['id']}')),
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

  testWidgets('Abgemeldet gibt es keine tote Glocke', (tester) async {
    await zeige(tester, angemeldet: false);
    expect(find.byType(IconButton), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Die Zahl zeigt, wie viel liegen geblieben ist',
      (tester) async {
    online.ungelesen = [
      meldung('n1', 'friend_request'),
      meldung('n2', 'beacon', subject: 's1'),
    ];
    await zeige(tester);

    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Nichts verpasst heißt auch nichts verpasst', (tester) async {
    await zeige(tester);
    expect(find.byType(Badge), findsNothing);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('Nichts verpasst 🍺'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Die Liste nennt, was passiert ist — mit Namen',
      (tester) async {
    online.ungelesen = [meldung('n1', 'beacon', subject: 's1')];
    await zeige(tester);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Anna ist auf ein Bier unterwegs'),
        findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Angesehen ist gelesen — aber nur die eine', (tester) async {
    online.ungelesen = [
      meldung('n1', 'beacon', subject: 's1'),
      meldung('n2', 'friend_request'),
    ];
    await zeige(tester);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('unterwegs'));
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('markRead:n1'));
    expect(online.aufrufe, isNot(contains('markRead:n2')),
        reason: 'Eine Meldung anzusehen erledigt nicht die anderen.');
    expect(find.text('Runde s1'), findsOneWidget,
        reason: 'Und sie führt dorthin, wo die Sache steht.');
    await abbauen(tester);
  });

  testWidgets('„Alle gelesen" räumt den ganzen Stapel', (tester) async {
    online.ungelesen = [
      meldung('n1', 'beacon', subject: 's1'),
      meldung('n2', 'friend_request'),
    ];
    await zeige(tester);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alle gelesen'));
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('markRead:n1,n2'));
    await abbauen(tester);
  });

  testWidgets('Ohne Ziel kein Pfeil', (tester) async {
    // Ein Pfeil verspricht einen Sprung. Bei einer Art, für die es kein
    // Ziel gibt, wäre das Versprechen leer.
    online.ungelesen = [meldung('n9', 'unbekannte_art')];
    await zeige(tester);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsNothing);
    await abbauen(tester);
  });
}
