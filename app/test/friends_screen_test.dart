import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/friends/friends_screen.dart';

import 'fake_online_service.dart';

/// Der Freundes-Bildschirm — bis 2026-08-15 zu 0,4 % abgedeckt
/// (Backlog B-5), obwohl hier die Einstellung sitzt, die steuert, **wer
/// den eigenen Aufenthaltsort sieht**.
///
/// Geprüft wird vor allem das Verhalten im Fehlerfall: Aus A-8 stammt die
/// Regel, dass ein fehlgeschlagener Serveraufruf nicht als Erfolg
/// dargestellt werden darf. Ohne Test wäre das eine Absichtserklärung.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  RemoteProfile profil(String id, String name,
          {FriendTier tier = FriendTier.freund}) =>
      RemoteProfile(
        id: id,
        username: name,
        displayName: name,
        avatarEmoji: '🍺',
        tier: tier,
      );

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
  });

  tearDown(() => db.close());

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => online),
        // Ohne angemeldeten Nutzer zeigt der Bildschirm nur den
        // Anmelde-Hinweis — genau der Zweig, der bisher als einziger
        // getestet war.
        onlineUserProvider.overrideWith((ref) => Stream.value(User(
              id: '11111111-1111-1111-1111-111111111111',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime(2026).toIso8601String(),
            ))),
      ],
      child: const MaterialApp(home: FriendsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Freunde erscheinen mit ihrem Kreis', (tester) async {
    online.freunde = [
      profil('f1', 'anna', tier: FriendTier.buddy),
      profil('f2', 'bert', tier: FriendTier.bekannter),
    ];

    await zeige(tester);

    expect(find.textContaining('anna'), findsWidgets);
    expect(find.textContaining('bert'), findsWidgets);
  });

  testWidgets('Offene Anfrage lässt sich annehmen', (tester) async {
    online.anfragen = [
      FriendRequest(friendshipId: 'fs1', from: profil('f9', 'clara')),
    ];

    await zeige(tester);
    expect(find.textContaining('clara'), findsWidgets);

    await tester.tap(find.byIcon(Icons.check_circle).first);
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('respondRequest:fs1:true'));
    expect(find.textContaining('Freunde'), findsWidgets);
  });

  testWidgets('Scheitert das Annehmen, sagt die App es und behauptet '
      'keinen Erfolg', (tester) async {
    online.anfragen = [
      FriendRequest(friendshipId: 'fs1', from: profil('f9', 'clara')),
    ];
    online.schlaegtFehl = true;

    await zeige(tester);
    await tester.tap(find.byIcon(Icons.check_circle).first);
    await tester.pumpAndSettle();

    // Der Kern der Regel aus A-8: kein „Ihr seid jetzt Freunde".
    expect(find.textContaining('Ihr seid jetzt Freunde'), findsNothing);
    expect(find.textContaining('nicht geklappt'), findsOneWidget);
    expect(find.textContaining('weiterhin offen'), findsOneWidget);
  });

  testWidgets('Scheitert das Entsperren, bleibt die Blockierung sichtbar '
      'und wird gemeldet', (tester) async {
    online.blockierte = [profil('b1', 'dora')];
    online.schlaegtFehl = true;

    await zeige(tester);
    expect(find.textContaining('dora'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Aufheben').first);
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('unblockProfile:b1'));
    expect(find.textContaining('aufgehoben'), findsNothing,
        reason: 'Eine Erfolgsmeldung wäre bei einer Sicherheitsentscheidung '
            'die gefährlichste Lüge.');
    expect(find.textContaining('besteht weiterhin'), findsOneWidget);
  });
}
