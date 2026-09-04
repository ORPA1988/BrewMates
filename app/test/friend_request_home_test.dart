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
/// Es gibt zwei Antworten, und beide sind Antworten. „Später" gab es bis
/// 0.10.12 als dritte Schaltfläche — sie blendete die Anfrage für die
/// Sitzung aus. Sie ist weg, seit das Ablehnen fünf Sekunden lang
/// zurücknehmbar ist: Der Grund für „Später" war, dass eine Antwort
/// endgültig war. Was bleibt, ist der ehrlichere Zustand — wer nicht
/// antworten will, antwortet nicht, und die Karte bleibt stehen.
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

  Widget umgebung(Widget kind) => ProviderScope(
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
    await tester.pumpWidget(umgebung(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(FriendRequestCard), findsOneWidget);
    expect(find.textContaining('Clara'), findsWidgets);
    for (final knopf in ['Annehmen', 'Ablehnen']) {
      expect(find.text(knopf), findsOneWidget, reason: '$knopf fehlt');
    }
    expect(find.text('Später'), findsNothing,
        reason: 'Eine Anfrage wegzuwischen half nur dem, der sie '
            'wegwischt — dem Wartenden nicht.');
    await abbauen(tester);
  });

  testWidgets('Annehmen meldet es dem Server', (tester) async {
    await tester.pumpWidget(umgebung(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annehmen'));
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('respondRequest:fs1:true'));
    await abbauen(tester);
  });

  testWidgets('Scheitert es, bleibt die Anfrage offen und die App sagt es',
      (tester) async {
    online.schlaegtFehl = true;
    await tester.pumpWidget(umgebung(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annehmen'));
    await tester.pumpAndSettle();

    // Regel aus A-8: kein Erfolg behaupten, der nicht stattfand.
    expect(find.textContaining('Ihr seid jetzt Freunde'), findsNothing);
    expect(find.textContaining('weiterhin offen'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Die Karte bleibt stehen, bis geantwortet ist',
      (tester) async {
    // Sie steht dort, weil ein Mensch auf eine Antwort wartet. Ohne
    // Antwort verschwindet sie nicht — das war der ganze Sinn, „Später"
    // zu streichen.
    await tester.pumpWidget(umgebung(const HomeScreen()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(FriendRequestCard), findsOneWidget);
    expect(online.aufrufe.where((a) => a.startsWith('respondRequest')),
        isEmpty);
    await abbauen(tester);
  });

  testWidgets('Ablehnen räumt die Karte weg und bietet „Rückgängig" an',
      (tester) async {
    await tester.pumpWidget(umgebung(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ablehnen'));
    // Einmal für den Neuaufbau, dann die Einblendung der Snackbar zu Ende
    // laufen lassen — solange sie hereinfährt, liegt ihre Schaltfläche
    // noch unterhalb des Bildschirms.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FriendRequestCard), findsNothing,
        reason: 'Die Anfrage verschwindet sofort — sonst wäre die '
            'Rückmeldung eine Lüge auf Zeit.');
    expect(find.textContaining('abgelehnt'), findsOneWidget);
    expect(find.text('Rückgängig'), findsOneWidget);
    // In der Frist ist noch nichts passiert. Genau darauf beruht der
    // Ausweg: Ein Aufruf, der nicht stattfand, muss nicht zurückgenommen
    // werden — und könnte es auch nicht (nur der Anfragende dürfte die
    // gelöschte `friendships`-Zeile wieder anlegen).
    expect(online.aufrufe.where((a) => a.startsWith('respondRequest')),
        isEmpty);

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(online.aufrufe.where((a) => a.startsWith('respondRequest')),
        isEmpty,
        reason: 'Nach „Rückgängig" darf der Aufruf nie kommen.');
    expect(find.byType(FriendRequestCard), findsOneWidget,
        reason: 'Die Anfrage ist wieder da.');
    await abbauen(tester);
  });

  testWidgets('Ohne „Rückgängig" geht die Ablehnung nach der Frist raus',
      (tester) async {
    await tester.pumpWidget(umgebung(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ablehnen'));
    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(online.aufrufe, contains('respondRequest:fs1:false'));
    await abbauen(tester);
  });

  testWidgets('Im Freunde-Bildschirm bleibt sie sichtbar', (tester) async {
    await tester.pumpWidget(umgebung(const FriendsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Clara'), findsWidgets,
        reason: 'Der Freunde-Bildschirm zeigt sie ebenfalls — dort hat '
            'der Mensch sie ja gesucht.');
    await abbauen(tester);
  });
}
