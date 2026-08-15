import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/friends/friends_screen.dart';
import 'package:brewmates/features/home/home_screen.dart';
import 'package:brewmates/widgets/friend_request_card.dart';

import 'fake_online_service.dart';

/// Freundschaftsanfragen auf der Startseite.
///
/// Sie standen bisher nur im Freunde-Bildschirm. Wer dort nicht hinsah,
/// liess jemanden wochenlang warten — und eine Anfrage ist die einzige
/// Stelle der App, an der ein anderer Mensch auf eine Antwort wartet.
///
/// Die drei Antworten sind nicht gleichwertig: „Annehmen" und „Ablehnen"
/// sind endgültig, „Später" ist es ausdrücklich **nicht**. Genau das
/// prüfen die Tests hier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService()
      ..anfragen = [
        FriendRequest(
          friendshipId: 'fs1',
          from: const RemoteProfile(
            id: 'p1',
            username: 'clara',
            displayName: 'Clara',
            avatarEmoji: '🍺',
          ),
        ),
      ];
  });

  Widget _umgebung(Widget kind) => ProviderScope(
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
        child: MaterialApp(home: kind),
      );

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Die Anfrage steht beim Start auf der Startseite',
      (tester) async {
    await tester.pumpWidget(_umgebung(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(FriendRequestCard), findsOneWidget);
    expect(find.textContaining('Clara'), findsWidgets);
    for (final knopf in ['Annehmen', 'Ablehnen', 'Später']) {
      expect(find.text(knopf), findsOneWidget, reason: '$knopf fehlt');
    }
    await abbauen(tester);
  });

  testWidgets('Annehmen meldet es dem Server', (tester) async {
    await tester.pumpWidget(_umgebung(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annehmen'));
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('respondRequest:fs1:true'));
    await abbauen(tester);
  });

  testWidgets('Scheitert es, bleibt die Anfrage offen und die App sagt es',
      (tester) async {
    online.schlaegtFehl = true;
    await tester.pumpWidget(_umgebung(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annehmen'));
    await tester.pumpAndSettle();

    // Regel aus A-8: kein Erfolg behaupten, der nicht stattfand.
    expect(find.textContaining('Ihr seid jetzt Freunde'), findsNothing);
    expect(find.textContaining('weiterhin offen'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('„Später" räumt nur die Startseite, nicht die Anfrage',
      (tester) async {
    await tester.pumpWidget(_umgebung(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendRequestCard), findsNothing);
    // Entscheidend: Es wurde NICHT geantwortet. „Später" heißt „nicht
    // jetzt", nicht „abgelehnt" — sonst wäre es die gefährlichste der
    // drei Schaltflächen.
    expect(online.aufrufe.where((a) => a.startsWith('respondRequest')),
        isEmpty);
    await abbauen(tester);
  });

  testWidgets('Im Freunde-Bildschirm bleibt sie sichtbar', (tester) async {
    await tester.pumpWidget(_umgebung(const FriendsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Clara'), findsWidgets,
        reason: '„Später" gilt nur für die Startseite — hier hat der '
            'Mensch die Anfragen ja gesucht.');
    await abbauen(tester);
  });
}
