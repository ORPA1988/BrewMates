import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/models.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/moderation/moderation_screen.dart';

import 'fake_online_service.dart';

/// Meldungen bearbeiten (Roadmap-Punkt, Issue #66).
///
/// Zwei Dinge sind hier prüfenswert und beide sind schon einmal in diesem
/// Projekt schiefgegangen: dass ein Bereich, der nur bestimmten Leuten
/// offensteht, das auch **anzeigt** statt leer zu bleiben — und dass ein
/// fehlgeschlagener Serveraufruf nicht als Erfolg aussieht (Regel A-8).
///
/// Die eigentliche Durchsetzung liegt am Server (`is_moderator` in Policy
/// und RPC, geprüft in `supabase/tests/moderation.test.sql`). Die
/// Oberfläche spiegelt sie nur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  ModerationReport meldung({String status = 'open', String? note}) =>
      ModerationReport(
        id: 'r1',
        subjectType: 'comment',
        reason: 'Beleidigende Nachricht im Kommentar',
        status: status,
        createdAt: DateTime(2026, 9, 1),
        reporterId: 'p1',
        reporterName: 'Anna',
        reportedId: 'p2',
        reportedName: 'Bert',
        note: note,
      );

  setUp(() async {
    // `formatDate` braucht die deutschen Namen — in der App erledigt das
    // `main()`, im Test muss es hier stehen.
    await initializeDateFormatting('de');
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService()..meldungen = [meldung()];
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
        child: const MaterialApp(home: ModerationScreen()),
      );

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Ohne Moderatorenrolle steht da, warum — nicht nichts',
      (tester) async {
    // Der leere Bildschirm wäre die schlechtere Antwort: Er sieht aus wie
    // „keine Meldungen" und ist in Wahrheit „nicht für dich".
    online.stufe = (level: 3, points: 120);
    await tester.pumpWidget(umgebung());
    await tester.pumpAndSettle();

    expect(find.text('Nur für Moderatoren'), findsOneWidget);
    expect(find.textContaining('Melden kann jeder'), findsOneWidget);
    expect(online.aufrufe.where((a) => a.startsWith('moderation.reports')),
        isEmpty,
        reason: 'Ohne Rolle fragt die App gar nicht erst.');
    await abbauen(tester);
  });

  testWidgets('Der Moderator sieht die offene Meldung mit beiden Namen',
      (tester) async {
    online.stufe = (level: 4, points: 0);
    await tester.pumpWidget(umgebung());
    await tester.pumpAndSettle();

    expect(find.textContaining('gemeldet: Bert'), findsOneWidget);
    expect(find.textContaining('von Anna'), findsOneWidget);
    expect(find.textContaining('Beleidigende Nachricht'), findsOneWidget);
    expect(find.text('Erledigen'), findsOneWidget);
    expect(find.text('Verwerfen'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Erledigen fragt nach dem Befund und schickt ihn mit',
      (tester) async {
    online.stufe = (level: 5, points: 0);
    await tester.pumpWidget(umgebung());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erledigen'));
    await tester.pumpAndSettle();

    expect(find.text('Meldung erledigen'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kommentar entfernt');
    // Zweimal „Erledigen" auf dem Bildschirm: einmal auf der Karte,
    // einmal im Dialog. Gemeint ist der im Dialog.
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Erledigen'),
    ));
    await tester.pumpAndSettle();

    expect(online.aufrufe,
        contains('moderation.resolve:r1:resolved:Kommentar entfernt'));
    expect(find.textContaining('erledigt'), findsWidgets);
    await abbauen(tester);
  });

  testWidgets('Abbrechen im Befund-Dialog ändert nichts', (tester) async {
    online.stufe = (level: 4, points: 0);
    await tester.pumpWidget(umgebung());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verwerfen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(online.aufrufe.where((a) => a.startsWith('moderation.resolve')),
        isEmpty);
    await abbauen(tester);
  });

  testWidgets('Scheitert der Server, behauptet die App keinen Erfolg',
      (tester) async {
    online.stufe = (level: 4, points: 0);
    online.schlaegtFehl = true;
    await tester.pumpWidget(umgebung());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erledigen'));
    await tester.pumpAndSettle();
    // Zweimal „Erledigen" auf dem Bildschirm: einmal auf der Karte,
    // einmal im Dialog. Gemeint ist der im Dialog.
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Erledigen'),
    ));
    await tester.pumpAndSettle();

    // Regel A-8. „Meldung erledigt." waere hier gelogen — und wer das
    // glaubt, sieht nicht mehr nach.
    expect(find.textContaining('Hat nicht geklappt'), findsOneWidget);
    expect(find.textContaining('Meldung erledigt'), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Eine erledigte Meldung zeigt Befund und Bearbeiter',
      (tester) async {
    online
      ..stufe = (level: 4, points: 0)
      ..meldungen = [meldung(status: 'resolved', note: 'Verwarnt')];
    await tester.pumpWidget(umgebung());
    await tester.pumpAndSettle();

    // Der offene Stapel ist leer …
    expect(find.textContaining('keine offenen Meldungen'), findsOneWidget);

    // … unter „Erledigt" steht sie mit allem, was dazugehoert.
    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('„Verwarnt"'), findsOneWidget);
    expect(find.text('Wieder öffnen'), findsOneWidget);
    await abbauen(tester);
  });
}
