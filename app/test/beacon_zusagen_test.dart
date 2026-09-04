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
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/session/session_detail_screen.dart';

import 'fake_online_service.dart';

/// „Session nicht gefunden" — und was daraus wurde.
///
/// **Der gemeldete Fehler.** Die Detailansicht kannte nur zwei Quellen:
/// die lokale Datenbank und die Liste der gerade laufenden Freundes-
/// Beacons. Wer über einen anderen Weg dort ankam, sah „Session nicht
/// gefunden" — und die anderen Wege sind die häufigen: die Glocke und der
/// Push tragen die blanke Server-UUID (kein `remote-` davor), der Aufruf
/// landete damit im Zweig für *eigene* Sessions und fragte die lokale
/// Datenbank nach einer fremden Session.
///
/// **Und was daraus wurde.** Ein Beacon ist eine Verabredung. Wer
/// draufklickt, will nicht lesen, sondern antworten: komme ich vorbei
/// oder nicht. Genau das steht jetzt oben auf dem Bildschirm.
const _ich = '11111111-1111-1111-1111-111111111111';
const _fremdeId = '50000000-0000-0000-0000-000000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  RemoteSession fremderBeacon() => RemoteSession(
        id: _fremdeId,
        host: const RemoteProfile(
          id: 'p2',
          username: 'anna',
          displayName: 'Anna',
          avatarEmoji: '🍺',
        ),
        venueName: 'Zum Goldenen Hirschen',
        message: 'Erstes Bier steht',
        startedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

  setUpAll(() async => initializeDateFormatting('de'));

  setUp(() {
    db = AppDatabase.memory();
    online = FakeOnlineService();
  });

  Future<void> zeige(WidgetTester tester, String id) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => online),
        onlineUserProvider.overrideWith((ref) => Stream.value(User(
              id: _ich,
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime(2026).toIso8601String(),
            ))),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/session/$id',
          routes: [
            GoRoute(
              path: '/session/:id',
              builder: (_, state) =>
                  SessionDetailScreen(sessionId: state.pathParameters['id']!),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Tippen und warten, bis die Antwort wirklich durch ist.
  ///
  /// `pumpAndSettle` allein reicht hier nicht. Eine **Zusage** prueft
  /// hinterher die Abzeichen, und das ist echte Arbeit an der lokalen
  /// Datenbank — die laeuft auf der richtigen Ereignisschleife, die der
  /// Widget-Test aber anhaelt. `pumpAndSettle` sieht dann keine Animation,
  /// kehrt sofort zurueck, und die Snackbar ist noch gar nicht da.
  /// (Bei einer **Absage** faellt das nicht auf: Absagen sammelt man
  /// nicht, also gibt es keine Abzeichen-Pruefung — deshalb war genau
  /// dieser Test gruen und der daneben rot.)
  ///
  /// `runAsync` gibt der echten Schleife eine Scheibe Zeit; danach pumpt
  /// der Test wie gewohnt.
  Future<void> tippen(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Eine blanke UUID aus der Glocke findet die Session',
      (tester) async {
    // Der gemeldete Fehler: Die Benachrichtigung trägt keine `remote-`-ID,
    // also fragte die Ansicht die lokale Datenbank nach einer fremden
    // Session — die dort nie steht.
    online.sessionsAmServer = {_fremdeId: fremderBeacon()};
    await zeige(tester, _fremdeId);

    expect(find.textContaining('nicht mehr zu sehen'), findsNothing);
    // Zweimal: in der Kopfzeile und als Teilnehmerin ihrer eigenen Runde.
    expect(find.text('Anna'), findsWidgets);
    expect(online.aufrufe, contains('sessions.byId:$_fremdeId'));
    await abbauen(tester);
  });

  testWidgets('Auch mit remote-Präfix, wenn die Liste sie nicht kennt',
      (tester) async {
    // Der Realtime-Strom baut beim Bildschirmwechsel neu auf; in diesen
    // Sekunden ist die Liste leer. Vorher hieß das „nicht gefunden".
    online.sessionsAmServer = {_fremdeId: fremderBeacon()};
    await zeige(tester, 'remote-$_fremdeId');

    expect(find.text('Anna'), findsWidgets);
    await abbauen(tester);
  });

  testWidgets('Kennt der Server sie nicht, sagt der Text warum',
      (tester) async {
    // Der Server unterscheidet bewusst nicht zwischen „vorbei" und „nicht
    // für dich" (RLS aus 0024). Der Satz muss deshalb beides abdecken —
    // und darf nicht klingen, als sei die App kaputt.
    await zeige(tester, _fremdeId);

    expect(find.textContaining('nicht mehr zu sehen'), findsOneWidget);
    expect(find.textContaining('drei Stunden'), findsOneWidget);
    expect(find.text('Session nicht gefunden'), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Der fremde Beacon fragt: Kommst du vorbei?', (tester) async {
    online.sessionsAmServer = {_fremdeId: fremderBeacon()};
    await zeige(tester, _fremdeId);

    expect(find.text('Kommst du vorbei?'), findsOneWidget);
    expect(find.text('Ich komme vorbei'), findsOneWidget);
    expect(find.text('Ich hab keine Zeit'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Zusagen meldet es dem Server', (tester) async {
    online.sessionsAmServer = {_fremdeId: fremderBeacon()};
    await zeige(tester, _fremdeId);

    await tippen(tester, 'Ich komme vorbei');

    expect(online.aufrufe, contains('antworten:$_fremdeId:joined'));
    expect(find.textContaining('Zugesagt'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Absagen ist eine Antwort, kein Nicht-Klick', (tester) async {
    online.sessionsAmServer = {_fremdeId: fremderBeacon()};
    await zeige(tester, _fremdeId);

    await tippen(tester, 'Ich hab keine Zeit');

    expect(online.aufrufe, contains('antworten:$_fremdeId:declined'));
    expect(find.textContaining('warten nicht auf dich'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Scheitert der Server, gibt es keine Zusage', (tester) async {
    // Regel A-8. Hier wiegt sie schwerer als sonst: Eine Zusage, die
    // niemanden erreicht, lässt jemanden warten.
    online
      ..sessionsAmServer = {_fremdeId: fremderBeacon()}
      ..schlaegtFehl = true;
    await zeige(tester, _fremdeId);

    await tippen(tester, 'Ich komme vorbei');

    expect(find.textContaining('nicht angekommen'), findsOneWidget);
    expect(find.textContaining('Zugesagt'), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Wer schon geantwortet hat, sieht seine Antwort',
      (tester) async {
    online
      ..sessionsAmServer = {_fremdeId: fremderBeacon()}
      ..teilnehmer = {
        _fremdeId: const [
          RemoteParticipant(
            profile: RemoteProfile(
                id: _ich,
                username: 'ich',
                displayName: 'Ich',
                avatarEmoji: '🍺'),
            art: Teilnahme.dabei,
          ),
        ],
      };
    await zeige(tester, _fremdeId);

    expect(find.text('Du kommst vorbei 🍻'), findsOneWidget);
    expect(find.text('Kommst du vorbei?'), findsNothing);
    // Änderbar bleibt sie: Ein Abend ist keine Buchung.
    expect(find.text('Doch nicht'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Absagen anderer stehen neben den Zusagen', (tester) async {
    // Der Kern der Funktion: „drei sind dabei" heißt wenig, solange offen
    // ist, ob die anderen noch überlegen oder längst abgesagt haben.
    online
      ..sessionsAmServer = {_fremdeId: fremderBeacon()}
      ..teilnehmer = {
        _fremdeId: const [
          RemoteParticipant(
            profile: RemoteProfile(
                id: 'p3',
                username: 'bert',
                displayName: 'Bert',
                avatarEmoji: '🧔'),
            art: Teilnahme.dabei,
          ),
          RemoteParticipant(
            profile: RemoteProfile(
                id: 'p4',
                username: 'clara',
                displayName: 'Clara',
                avatarEmoji: '👩'),
            art: Teilnahme.abgesagt,
          ),
        ],
      };
    await zeige(tester, _fremdeId);

    expect(find.text('Bert'), findsOneWidget);
    expect(find.text('Kann heute nicht'), findsOneWidget);
    expect(find.text('Clara'), findsOneWidget);
    await abbauen(tester);
  });
}
