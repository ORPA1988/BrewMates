// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/core/theme.dart';
import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/models.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/home/home_screen.dart';

import 'fake_online_service.dart';

/// Verabredungen — „Freitag 19 Uhr" statt „ich sitze jetzt hier".
///
/// **Warum sie nur am Server leben.** Ein Beacon ergibt auch offline
/// Sinn: Er ist ein Zustand, den das Gerät kennt. Eine Verabredung
/// dagegen, von der niemand erfährt, ist keine. Deshalb gibt es sie in
/// der lokalen Datenbank gar nicht — und deshalb muss ein Fehlschlag
/// beim Anlegen sichtbar sein, statt in einer Warteschlange zu landen,
/// die ihn Stunden später bei Leuten abliefert, für die der Termin
/// vorbei ist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
  });

  tearDown(() => db.close());

  List<Override> mitServer() => [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => online),
        onlineUserProvider.overrideWith((ref) => Stream.value(User(
              id: '11111111-1111-1111-1111-111111111111',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime(2026).toIso8601String(),
            ))),
      ];

  RemoteSession verabredung(DateTime wann, {String? wo, String? text}) =>
      RemoteSession(
        id: 'v1',
        host: const RemoteProfile(
          id: 'ben',
          username: 'ben',
          displayName: 'Ben',
          avatarEmoji: '🍻',
        ),
        venueName: wo,
        message: text,
        startedAt: wann,
        expiresAt: wann.add(const Duration(hours: 3)),
        scheduledFor: wann,
      );

  group('Anlegen', () {
    test('Ohne Verbindung entsteht keine Verabredung', () async {
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => null),
      ]);
      addTearDown(c.dispose);

      final ok = await c.read(actionsProvider).planSession(
            scheduledFor: DateTime.now().add(const Duration(days: 1)),
            venueName: 'Augustiner',
          );

      expect(ok, isFalse,
          reason: 'und der Bildschirm sagt das, statt „gespeichert"');
    });

    test('Ein Fehlschlag am Server wird weitergereicht', () async {
      online.schlaegtFehl = true;
      final c = ProviderContainer(overrides: mitServer());
      addTearDown(c.dispose);

      final ok = await c.read(actionsProvider).planSession(
            scheduledFor: DateTime.now().add(const Duration(days: 1)),
          );

      expect(ok, isFalse);
    });

    test('Sonst kommt sie an', () async {
      final c = ProviderContainer(overrides: mitServer());
      addTearDown(c.dispose);

      final termin = DateTime(2026, 9, 11, 19);
      final ok = await c
          .read(actionsProvider)
          .planSession(scheduledFor: termin, venueName: 'Augustiner');

      expect(ok, isTrue);
      expect(online.aufrufe,
          contains('planSession:${termin.toIso8601String()}'));
    });
  });

  group('Anzeigen', () {
    testWidgets('„Demnächst" zeigt die Verabredung mit Termin und Ort',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      online.verabredungen = [
        verabredung(DateTime(2026, 9, 11, 19), wo: 'Augustiner'),
      ];

      await tester.pumpWidget(ProviderScope(
        overrides: mitServer(),
        child: MaterialApp(
          theme: BrewTheme.light,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          home: const HomeScreen(),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Demnächst 📅'), findsOneWidget);
      expect(find.textContaining('Ben'), findsWidgets);
      expect(find.textContaining('Augustiner'), findsWidgets);
      // Der Termin steht als Datum und Uhrzeit da, nicht als Restlaufzeit.
      expect(find.textContaining('19:00 Uhr'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Ohne Verabredungen fehlt der Abschnitt ganz',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: mitServer(),
        child: MaterialApp(
          theme: BrewTheme.light,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          home: const HomeScreen(),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      // Keine leere Überschrift: Ein Abschnitt ohne Inhalt ist kein
      // Abschnitt.
      expect(find.text('Demnächst 📅'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
