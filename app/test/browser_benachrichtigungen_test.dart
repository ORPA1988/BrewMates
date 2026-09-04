// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/models.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/shell/app_shell.dart';

import 'fake_online_service.dart';

/// Benachrichtigungen, solange die Web-App offen ist (Issue #63).
///
/// **Was hier geprüft wird und was nicht.** Die `Notification`-API des
/// Browsers lässt sich im Widget-Test nicht betreiben — sie braucht einen
/// echten Browser und eine erteilte Erlaubnis. Prüfbar ist aber genau
/// das, was Fehler machen kann: die **Verzweigung**. Drei Fälle, drei
/// Wege, und der dritte ist der, der ohne diese Änderung verloren ging.
///
/// Die stumme Fassung von [Browserfenster] meldet „immer sichtbar" —
/// deshalb bleibt das Verhalten auf Android und Windows unverändert, und
/// auch das steht hier als Test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;
  late _FakesFenster fenster;
  late StreamController<RemoteNotification> meldungen;

  RemoteNotification anfrage() => RemoteNotification(
        id: 'n1',
        type: 'friend_request',
        createdAt: DateTime(2026, 9, 3),
        actor: const RemoteProfile(
          id: 'p1',
          username: 'clara',
          displayName: 'Clara',
          avatarEmoji: '🍺',
        ),
      );

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
    fenster = _FakesFenster();
    meldungen = StreamController<RemoteNotification>.broadcast();
  });

  tearDown(() async {
    await meldungen.close();
    fenster.dispose();
  });

  Future<void> zeige(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => AppShell(shell: shell),
          branches: [
            for (final pfad in ['/', '/feed', '/map', '/discover', '/profile'])
              StatefulShellBranch(routes: [
                GoRoute(
                  path: pfad,
                  builder: (_, __) => Scaffold(body: Text('Seite $pfad')),
                ),
              ]),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => online),
        browserfensterProvider.overrideWithValue(fenster),
        incomingNotificationsProvider
            .overrideWith((ref) => meldungen.stream),
        onlineUserProvider.overrideWith((ref) => Stream.value(User(
              id: '11111111-1111-1111-1111-111111111111',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime(2026).toIso8601String(),
            ))),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Liegt die App vorn, bleibt es beim Banner', (tester) async {
    // Das ist der Zustand auf Android, unter Windows und in jedem Test:
    // Die stumme Fassung meldet immer „sichtbar".
    await zeige(tester);
    meldungen.add(anfrage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Clara'), findsOneWidget);
    expect(fenster.gezeigt, isEmpty,
        reason: 'Keine Systemmeldung, wenn der Mensch ohnehin hinsieht.');
    await abbauen(tester);
  });

  testWidgets('Tab im Hintergrund und Erlaubnis erteilt: Systemmeldung',
      (tester) async {
    fenster
      ..sichtbarSetzen(false)
      ..erlaubnis = 'granted';
    await zeige(tester);
    meldungen.add(anfrage());
    await tester.pump();

    expect(fenster.gezeigt, hasLength(1));
    expect(fenster.gezeigt.single.text, contains('Clara'));
    expect(fenster.gezeigt.single.tag, 'friend_request',
        reason: 'Gleiche Art ersetzt sich, statt sich zu stapeln.');
    await abbauen(tester);
  });

  testWidgets('Ohne Erlaubnis wird gemerkt und beim Zurückkommen gezeigt',
      (tester) async {
    // Der wichtigste Fall: Auf dem iPhone gibt es außerhalb einer
    // installierten Web-App gar keine Systemmeldungen. Ohne das Merken
    // wäre die Meldung schlicht weg.
    fenster
      ..sichtbarSetzen(false)
      ..erlaubnis = 'default';
    await zeige(tester);
    meldungen.add(anfrage());
    await tester.pump();

    expect(fenster.gezeigt, isEmpty);
    expect(find.textContaining('Clara'), findsNothing,
        reason: 'Solange der Tab hinten liegt, sieht das ohnehin niemand.');

    fenster.sichtbarSetzen(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Clara'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Mehrere verpasste Meldungen werden gezählt, nicht gestapelt',
      (tester) async {
    fenster
      ..sichtbarSetzen(false)
      ..erlaubnis = 'denied';
    await zeige(tester);
    meldungen
      ..add(anfrage())
      ..add(anfrage());
    await tester.pump();

    fenster.sichtbarSetzen(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('2 neue Meldungen'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Nichts verpasst, nichts zu melden', (tester) async {
    fenster.sichtbarSetzen(false);
    await zeige(tester);
    fenster.sichtbarSetzen(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsNothing,
        reason: 'Ein Banner ohne Inhalt wäre nur Lärm.');
    await abbauen(tester);
  });

  test('Die stumme Fassung ändert außerhalb des Browsers nichts', () {
    final stumm = Browserfenster();
    expect(stumm.sichtbar, isTrue);
    expect(stumm.benachrichtigungenMoeglich, isFalse);
    expect(stumm.erlaubnis, Browserfenster.nichtVerfuegbar);
    // Darf nicht werfen — die Hülle ruft es ungeprüft auf.
    stumm.zeige(text: 'egal');
  });
}

/// Ein Fenster, das der Test steuert.
class _FakesFenster implements Browserfenster {
  final _sichtbarkeit = StreamController<bool>.broadcast();
  bool _sichtbar = true;

  final List<({String text, String? tag})> gezeigt = [];

  @override
  String erlaubnis = 'default';

  void sichtbarSetzen(bool wert) {
    _sichtbar = wert;
    _sichtbarkeit.add(wert);
  }

  void dispose() => _sichtbarkeit.close();

  @override
  bool get benachrichtigungenMoeglich =>
      erlaubnis != Browserfenster.nichtVerfuegbar;

  @override
  Future<String> erlaubnisAnfragen() async => erlaubnis;

  @override
  bool get sichtbar => _sichtbar;

  @override
  Stream<bool> get sichtbarkeit => _sichtbarkeit.stream;

  @override
  void zeige({
    required String text,
    String? tag,
    void Function()? beiKlick,
  }) =>
      gezeigt.add((text: text, tag: tag));
}
