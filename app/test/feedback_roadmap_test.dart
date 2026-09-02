import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/feedback/feedback_screen.dart';
import 'package:brewmates/features/feedback/roadmap_screen.dart';
import 'package:brewmates/features/home/home_screen.dart';

import 'fake_online_service.dart';

/// Feedback und Roadmap (Testphase) sowie die Reaktionen auf eigene
/// Sessions, die der Gastgeber bis 2026-09-03 nie zu sehen bekam.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  setUp(() async {
    // Die Meldungsliste formatiert Daten deutsch — wie main() es tut.
    await initializeDateFormatting('de');
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
  });

  Widget umgebung(Widget kind, {bool angemeldet = true}) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineServiceProvider.overrideWith((ref) async => online),
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
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/start',
            routes: [
              GoRoute(path: '/start', builder: (_, __) => kind),
              GoRoute(
                path: '/feedback',
                builder: (_, state) => FeedbackScreen(
                    initialKind: state.uri.queryParameters['art'] == 'wish'
                        ? FeedbackKind.wish
                        : FeedbackKind.bug),
              ),
              GoRoute(
                  path: '/roadmap', builder: (_, __) => const RoadmapScreen()),
              GoRoute(
                  path: '/beacon',
                  builder: (_, __) => const Scaffold(body: Text('Beacon'))),
              GoRoute(
                  path: '/scan',
                  builder: (_, __) => const Scaffold(body: Text('Scan'))),
              GoRoute(
                  path: '/checkin',
                  builder: (_, __) => const Scaffold(body: Text('Checkin'))),
            ],
          ),
        ),
      );

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Die drei Knöpfe stehen unter „Zusammenkommen" — nur wenn '
      'der Schalter an ist', (tester) async {
    await tester.pumpWidget(umgebung(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Fehler'), findsOneWidget);
    expect(find.text('Wunsch'), findsOneWidget);
    expect(find.text('Roadmap'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Schalter aus → keine Knöpfe (abschaltbar ohne Release)',
      (tester) async {
    online.feedbackAn = false;
    await tester.pumpWidget(umgebung(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Roadmap'), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Fehler melden schickt Text, Version und Plattform mit',
      (tester) async {
    await tester.pumpWidget(umgebung(const FeedbackScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField), 'Prost gedrückt, beim Gastgeber kam nichts an.');
    await tester.tap(find.text('Fehler melden'));
    await tester.pumpAndSettle();

    final aufruf = online.aufrufe.firstWhere((a) => a.startsWith('feedback.submit'));
    expect(aufruf, contains(':bug:'));
    expect(aufruf, contains('Prost gedrückt'));
    expect(aufruf, contains('android'),
        reason: 'Widget-Tests laufen als Android — die Plattform muss mit.');
    // Nachvollziehbarkeit: Die Meldung erscheint sofort unten mit Status.
    // Die Liste liegt unter dem Formular und kann ausserhalb des
    // sichtbaren Bereichs sein — deshalb skipOffstage: false.
    expect(online.meineMeldungen.single.status, FeedbackStatus.open);
    // Die Liste liegt unter dem Formular; eine ListView baut nur, was im
    // Bild ist. Also hinscrollen, statt offstage zu suchen.
    await tester.scrollUntilVisible(find.text('Eingegangen'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Eingegangen'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Scheitert das Senden, wird kein Dank angezeigt',
      (tester) async {
    online.schlaegtFehl = true;
    await tester.pumpWidget(umgebung(const FeedbackScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Irgendwas geht nicht.');
    await tester.tap(find.text('Fehler melden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Danke'), findsNothing);
    expect(find.textContaining('Konnte nicht gesendet'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Roadmap zeigt drei Gruppen in Alltagssprache', (tester) async {
    online.roadmap = const [
      RoadmapItem(id: 'r1', title: 'Push, wenn ein Freund losgeht',
          summary: 'Dein Telefon meldet sich.', status: RoadmapStatus.planned),
      RoadmapItem(id: 'r2', title: 'Beacon auf zwei Geräten',
          summary: 'Telefon und Browser zeigen dasselbe.', status: RoadmapStatus.done),
    ];
    await tester.pumpWidget(umgebung(const RoadmapScreen()));
    await tester.pumpAndSettle();
    expect(find.text('🗓️ Geplant'), findsOneWidget);
    expect(find.text('✅ Fertig'), findsOneWidget);
    expect(find.text('Push, wenn ein Freund losgeht'), findsOneWidget);
    expect(find.text('Beacon auf zwei Geräten'), findsOneWidget);
    await abbauen(tester);
  });

  test('Der Gastgeber sieht, wer zugeprostet hat', () async {
    online.teilnehmer = {
      's1': const [
        RemoteParticipant(
            profile: RemoteProfile(id: 'p2', username: 'bert',
                displayName: 'Bert', avatarEmoji: '🍺'),
            joined: false),
      ],
    };
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      onlineServiceProvider.overrideWith((ref) async => online),
      onlineUserProvider.overrideWith((ref) => Stream.value(User(
            id: '11111111-1111-1111-1111-111111111111',
            appMetadata: const {}, userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime(2026).toIso8601String(),
          ))),
    ]);
    addTearDown(c.dispose);
    // autoDispose: ohne Zuhoerer wird der Provider beim Laden entsorgt.
    c.listen(remoteParticipantsProvider('s1'), (_, __) {});
    final liste = await c.read(remoteParticipantsProvider('s1').future);
    expect(liste.single.profile.displayName, 'Bert');
    expect(liste.single.joined, isFalse);
    await db.close();
  });
}
