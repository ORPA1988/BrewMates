// Gemeinsame Challenges einer Crew (#132, Migration 0062).
//
// Die Rechenregel steht am Server und wird dort geprüft
// (`crew_challenges.test.sql`). Hier zählt, dass die App den
// **gemeinsamen** Stand zeigt und nicht heimlich selbst rechnet.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/models.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/crews/crew_detail_screen.dart';

import 'fake_online_service.dart';

const _ich = '11111111-1111-1111-1111-111111111111';

RemoteProfile _profil(String id, String name) => RemoteProfile(
      id: id,
      username: name.toLowerCase(),
      displayName: name,
      avatarEmoji: '🍺',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService fake;

  setUp(() {
    db = AppDatabase.memory();
    fake = FakeOnlineService();
    fake.crews_ = [
      const RemoteCrew(
        id: 'crew1',
        name: 'Testcrew',
        emoji: '🍻',
        ownerId: _ich,
        memberCount: 2,
      ),
    ];
    fake.crewMitglieder = [
      (profile: _profil(_ich, 'Ich'), role: 'owner'),
      (profile: _profil('m1', 'Mitglied'), role: 'member'),
    ];
  });

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => fake),
      ],
      child: const MaterialApp(home: CrewDetailScreen(crewId: 'crew1')),
    ));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Gemeinsame Challenges'),
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Der Stand kommt vom Server, nicht aus eigener Rechnung',
      (tester) async {
    fake.crewChallengeZeilen = [
      {
        'id': 'ch1',
        'title': 'Stil-Safari',
        'description': 'Gemeinsam für die Crew.',
        'emoji': '🦁',
        'rule': {'type': 'distinct_styles', 'threshold': 10},
        'starts_at': '2026-09-01T00:00:00Z',
        'ends_at': '2026-10-01T00:00:00Z',
      },
    ];
    fake.crewChallengeStand = {'ch1': 7};

    await zeige(tester);

    expect(find.text('Stil-Safari'), findsOneWidget);
    expect(find.text('7/10'), findsOneWidget);
    // Und die App hat wirklich gefragt, statt zu rechnen.
    expect(fake.aufrufe, contains('crewChallengeProgress:ch1'));

    await abbauen(tester);
  });

  testWidgets('Über dem Ziel bleibt der Balken voll', (tester) async {
    fake.crewChallengeZeilen = [
      {
        'id': 'ch1',
        'title': 'Übererfüllt',
        'description': '',
        'emoji': '🏆',
        'rule': {'type': 'checkins_count', 'threshold': 5},
        'starts_at': '2026-09-01T00:00:00Z',
        'ends_at': '2026-10-01T00:00:00Z',
      },
    ];
    fake.crewChallengeStand = {'ch1': 12};

    await zeige(tester);

    expect(find.text('12/5'), findsOneWidget);
    final balken = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator).first);
    expect(balken.value, 1.0, reason: '„240 %" sagt nichts');

    await abbauen(tester);
  });

  testWidgets('Der Gründer darf eine anlegen', (tester) async {
    await zeige(tester);
    expect(find.text('Neu'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Eine Regel ohne Ziel wird übergangen', (tester) async {
    // Eine Challenge ohne `threshold` hätte einen Balken ohne Bezug.
    fake.crewChallengeZeilen = [
      {
        'id': 'kaputt',
        'title': 'Ohne Ziel',
        'description': '',
        'emoji': '🏆',
        'rule': {'type': 'checkins_count'},
        'starts_at': '2026-09-01T00:00:00Z',
        'ends_at': '2026-10-01T00:00:00Z',
      },
    ];

    await zeige(tester);

    expect(find.text('Ohne Ziel'), findsNothing);
    expect(find.textContaining('Noch keine'), findsOneWidget);

    await abbauen(tester);
  });
}
