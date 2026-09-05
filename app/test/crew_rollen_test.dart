// Rollen in einer Crew (#132, Migrationen 0060/0061).
//
// Wer was darf, entscheidet der Server — geprüft in
// `supabase/tests/crew_verwalter.test.sql`. Hier geht es um die Frage,
// ob die Oberfläche dieselben Grenzen zeigt: Ein Knopf, der abgewiesen
// würde, ist schlimmer als keiner.
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

/// Die Kennung, unter der `FakeOnlineService` angemeldet ist.
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
  });

  Future<void> zeige(WidgetTester tester, {required String meineRolle}) async {
    fake.crews_ = [
      RemoteCrew(
        id: 'crew1',
        name: 'Testcrew',
        emoji: '🍻',
        ownerId: meineRolle == 'owner' ? _ich : 'fremd',
        memberCount: 3,
      ),
    ];
    // Genau **ein** Gründer, sonst beschreibt der Testfall eine Crew,
    // die es nicht geben kann: Wem sie gehört, steht in `owner_id`.
    fake.crewMitglieder = meineRolle == 'owner'
        ? [
            (profile: _profil(_ich, 'Ich'), role: 'owner'),
            (profile: _profil('m1', 'Mitglied'), role: 'member'),
          ]
        : [
            (profile: _profil('fremd', 'Gründerin'), role: 'owner'),
            (profile: _profil(_ich, 'Ich'), role: meineRolle),
            (profile: _profil('m1', 'Mitglied'), role: 'member'),
          ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => fake),
      ],
      child: const MaterialApp(home: CrewDetailScreen(crewId: 'crew1')),
    ));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    // Die Mitgliederliste steht unter Einladung, QR-Code und Bilanz —
    // ohne Scrollen ist sie im Test gar nicht gebaut.
    await tester.dragUntilVisible(
      find.text('Mitglieder'),
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

  testWidgets('Rollen stehen an der Zeile', (tester) async {
    await zeige(tester, meineRolle: 'admin');
    expect(find.text('Gründer'), findsOneWidget);
    expect(find.text('Verwalter'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Ein einfaches Mitglied bekommt keine Knöpfe', (tester) async {
    await zeige(tester, meineRolle: 'member');
    expect(find.byIcon(Icons.more_vert), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Der Verwalter darf entfernen, aber keine Rollen vergeben',
      (tester) async {
    await zeige(tester, meineRolle: 'admin');

    // Zwei Zeilen sind bedienbar: die eigene und die des Mitglieds —
    // die des Gründers nicht.
    expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    expect(find.text('Aus der Crew entfernen'), findsOneWidget);
    expect(find.text('Zum Verwalter machen'), findsNothing);

    await tester.tapAt(const Offset(10, 10)); // Menü schließen
    await tester.pumpAndSettle();
    await abbauen(tester);
  });

  testWidgets('Der Gründer darf beides', (tester) async {
    await zeige(tester, meineRolle: 'owner');
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    expect(find.text('Zum Verwalter machen'), findsOneWidget);
    expect(find.text('Aus der Crew entfernen'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await abbauen(tester);
  });

  testWidgets('Am Gründer selbst gibt es nichts zu tun', (tester) async {
    await zeige(tester, meineRolle: 'owner');
    // Zwei Mitglieder, aber nur eine bedienbare Zeile: die eigene —
    // die des Gründers — trägt keinen Knopf. Er kann sich weder
    // entfernen noch umstufen, und die Datenbank sagt dasselbe.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await abbauen(tester);
  });
}
