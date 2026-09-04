import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/account/account_screen.dart';

import 'fake_online_service.dart';

/// Der Anmeldebildschirm zeigt genau die Wege, die der Server nennt.
///
/// **Warum das auf dem Bildschirm geprüft wird und nicht am Provider:**
/// Ein Provider kann tadellos die richtige Liste liefern, während der
/// Bildschirm weiterhin seinen fest verdrahteten Knopf zeichnet. Genau
/// dieser Fehler ist in diesem Projekt schon einmal passiert (Bierlaune,
/// PR #82/#94) — die Prüfung gehört dorthin, wo der Mensch hinsieht.
class _FakeMitVerfahren extends FakeOnlineService {
  List<Anmeldeverfahren> verfahren = const [];

  @override
  Future<List<Anmeldeverfahren>> verfuegbareAnmeldeverfahren() async =>
      verfahren;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late _FakeMitVerfahren online;

  setUp(() {
    db = AppDatabase.memory();
    online = _FakeMitVerfahren();
  });

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => online),
        // Abgemeldet — nur dann gibt es überhaupt Anmeldeknöpfe.
        onlineUserProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const MaterialApp(home: AccountScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Nennt der Server zwei Wege, stehen zwei Knöpfe da',
      (tester) async {
    online.verfahren = const [Anmeldeverfahren.google, Anmeldeverfahren.apple];
    await zeige(tester);

    expect(find.text('Mit Google anmelden'), findsOneWidget);
    expect(find.text('Mit Apple anmelden'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Was der Server nicht nennt, steht auch nicht da',
      (tester) async {
    // Der Kern der Sache: Ein Knopf für einen Anbieter, der nicht
    // eingerichtet ist, antwortet „provider is not enabled" — und wer
    // sich nicht anmelden kann, kommt nicht wieder.
    online.verfahren = const [Anmeldeverfahren.google];
    await zeige(tester);

    expect(find.text('Mit Google anmelden'), findsOneWidget);
    expect(find.text('Mit Apple anmelden'), findsNothing);
    expect(find.text('Mit GitHub anmelden'), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Die Reihenfolge ist die des Servers', (tester) async {
    online.verfahren = const [Anmeldeverfahren.apple, Anmeldeverfahren.google];
    await zeige(tester);

    final apple = tester.getTopLeft(find.text('Mit Apple anmelden')).dy;
    final google = tester.getTopLeft(find.text('Mit Google anmelden')).dy;
    expect(apple, lessThan(google));
    await abbauen(tester);
  });

  testWidgets('Sagt der Server gar nichts, bleibt Google stehen',
      (tester) async {
    // Ein Anmeldebildschirm ganz ohne Knopf wäre die schlechteste
    // Antwort auf ein Verbindungsproblem: eine Sackgasse.
    online.verfahren = const [];
    await zeige(tester);

    expect(find.text('Mit Google anmelden'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('E-Mail und Passwort bleiben unabhängig davon erreichbar',
      (tester) async {
    // Der Weg ohne fremden Anbieter darf nie von einer Serverliste
    // abhängen — sonst hinge das Anmelden an einer Konfiguration.
    online.verfahren = const [Anmeldeverfahren.github];
    await zeige(tester);

    expect(find.text('Mit GitHub anmelden'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
    await abbauen(tester);
  });
}
