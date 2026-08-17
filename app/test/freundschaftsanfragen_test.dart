import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/friends/friends_screen.dart';
import 'package:brewmates/features/friends/qr_scan_screen.dart';

import 'fake_online_service.dart';

/// Freundschaftsanfragen: stellen, sehen, zurücknehmen.
///
/// Zwei Löcher, die dieselbe Wurzel hatten — eine gestellte Anfrage war
/// unsichtbar:
///
/// 1. Der QR-Scan **stellte gar keine Anfrage**. Er suchte das Profil und
///    wartete auf einen zweiten Tipp. Für den Menschen davor sah das aus
///    wie eine reine Suche: Telefon einstecken, und beim anderen kam nie
///    etwas an.
/// 2. Wer eine Anfrage gestellt hatte, sah davon nichts mehr und konnte
///    sie nicht zurücknehmen. Ein Fehlgriff war endgültig.
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
    online = FakeOnlineService()..profileNachId = {clara.id: clara};
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

  testWidgets('Der Scan stellt die Anfrage selbst', (tester) async {
    await tester.pumpWidget(umgebung(const QrScanScreen()));
    await tester.pumpAndSettle();

    // Den Scan nachstellen: Der Bildschirm bekommt die Nutzlast, die die
    // Kamera liefern wuerde. Die Kamera selbst laesst sich im Test nicht
    // betreiben — der Weg dahinter schon, und dort sass der Fehler.
    final zustand = tester.state(find.byType(QrScanScreen));
    // ignore: avoid_dynamic_calls
    await (zustand as dynamic).handleCodeForTest('brewmates:friend:${clara.id}');
    await tester.pumpAndSettle();

    // Der Kern: Es wurde gesendet, nicht bloss gesucht.
    expect(online.aufrufe, contains('sendFriendRequest:${clara.id}'));
    expect(find.textContaining('Anfrage ist raus'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Nach dem Scan lässt sich die Anfrage zurücknehmen',
      (tester) async {
    await tester.pumpWidget(umgebung(const QrScanScreen()));
    await tester.pumpAndSettle();

    final zustand = tester.state(find.byType(QrScanScreen));
    // ignore: avoid_dynamic_calls
    await (zustand as dynamic).handleCodeForTest('brewmates:friend:${clara.id}');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();

    expect(online.aufrufe.any((a) => a.startsWith('withdrawRequest:')), isTrue);
    expect(online.gestellteAnfragen, isEmpty);
    await abbauen(tester);
  });

  testWidgets('Ein fremder QR-Code stellt keine Anfrage', (tester) async {
    await tester.pumpWidget(umgebung(const QrScanScreen()));
    await tester.pumpAndSettle();

    final zustand = tester.state(find.byType(QrScanScreen));
    // ignore: avoid_dynamic_calls
    await (zustand as dynamic).handleCodeForTest('WIFI:S=Gasthaus;P=bier;;');
    await tester.pumpAndSettle();

    // Jetzt, wo der Scan direkt sendet, traegt das Praefix die ganze Last:
    // Ohne es wuerde jeder Speisekarten- oder WLAN-Code eine Anfrage
    // ausloesen, und zwar ohne Rueckfrage.
    expect(online.aufrufe.where((a) => a.startsWith('sendFriendRequest')),
        isEmpty);
    expect(find.textContaining('kein BrewMates-Code'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Gestellte Anfragen stehen im Freunde-Bildschirm',
      (tester) async {
    online.gestellteAnfragen = const [
      OutgoingRequest(friendshipId: 'fs1', to: clara),
    ];
    await tester.pumpWidget(umgebung(const FriendsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Von dir angefragt'), findsOneWidget);
    expect(find.text('wartet auf Antwort'), findsOneWidget);

    await tester.tap(find.text('Zurücknehmen'));
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('withdrawRequest:fs1'));
    await abbauen(tester);
  });

  testWidgets('Scheitert das Zurücknehmen, wird kein Erfolg behauptet',
      (tester) async {
    online.gestellteAnfragen = const [
      OutgoingRequest(friendshipId: 'fs1', to: clara),
    ];
    online.schlaegtFehl = true;
    await tester.pumpWidget(umgebung(const FriendsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zurücknehmen'));
    await tester.pumpAndSettle();

    // Regel aus A-8.
    expect(find.textContaining('zurückgenommen'), findsNothing);
    expect(find.textContaining('Hat nicht geklappt'), findsOneWidget);
    await abbauen(tester);
  });
}
