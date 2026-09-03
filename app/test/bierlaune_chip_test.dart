import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/home/home_screen.dart';

import 'fake_online_service.dart';

/// Die Bierlaune auf der Startseite.
///
/// **Warum es diesen Test gibt.** Der Ablauf am 30-Sekunden-Takt war
/// gebaut und geprüft — aber nur als Provider. Die Startseite rechnete
/// weiter mit `DateTime.now()` beim Bauen, weil eine Ersetzung im
/// Werkzeug abgebrochen war, bevor die Datei geschrieben wurde. Der Test
/// dazu lief grün, weil er den Provider prüfte und nicht den Bildschirm.
///
/// Ein Provider, den niemand ansieht, ändert nichts. Dieser Test sieht
/// auf den Bildschirm.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;
  late StreamController<DateTime> uhr;

  final start = DateTime(2026, 9, 3, 20, 0);

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService()
      ..thirstyBis = start.add(const Duration(minutes: 2));
    uhr = StreamController<DateTime>.broadcast();
  });

  Future<void> zeige(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => online),
        clockProvider.overrideWith((ref) => uhr.stream),
        onlineUserProvider.overrideWith((ref) => Stream.value(User(
              id: '11111111-1111-1111-1111-111111111111',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime(2026).toIso8601String(),
            ))),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> stelleUhr(WidgetTester tester, DateTime t) async {
    uhr.add(t);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await uhr.close();
    await db.close();
  }

  testWidgets('läuft von selbst ab — auf dem Bildschirm, nicht nur im '
      'Provider', (tester) async {
    await zeige(tester);
    await stelleUhr(tester, start);
    expect(find.textContaining('Bierlaune bis'), findsOneWidget);

    // Drei Minuten weiter, noch im selben Fünf-Minuten-Abruftakt: Es wird
    // NICHT neu geholt, und trotzdem muss der Chip umschlagen.
    await stelleUhr(tester, start.add(const Duration(minutes: 3)));

    expect(find.textContaining('Bierlaune bis'), findsNothing,
        reason: 'Der Chip darf nicht „bis 20:02" zeigen, wenn es 20:03 ist.');
    expect(find.text('🍺 Bierlaune!'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('ein Tipp auf die laufende Bierlaune beendet sie nicht sofort',
      (tester) async {
    // Vorher war der Chip ein Umschalter: ein Tipp, und die Bierlaune war
    // ersatzlos weg. Dieselbe Fehltipp-Falle, die beim Beacon längst
    // geschlossen ist.
    await zeige(tester);
    await stelleUhr(tester, start);

    await tester.tap(find.textContaining('Bierlaune bis'));
    await tester.pumpAndSettle();

    expect(find.textContaining('läuft bis'), findsOneWidget);
    expect(find.text('Bierlaune beenden'), findsOneWidget);
    expect(online.aufrufe.where((a) => a.startsWith('setBierlaune')), isEmpty,
        reason: 'Der Zettel fragt erst.');
    await abbauen(tester);
  });

  testWidgets('im Zettel lässt sich die Laufzeit ändern', (tester) async {
    await zeige(tester);
    await stelleUhr(tester, start);
    await tester.tap(find.textContaining('Bierlaune bis'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('noch 2 Stunden'));
    await tester.pumpAndSettle();

    expect(online.aufrufe.where((a) => a.startsWith('setBierlaune')),
        isNotEmpty,
        reason: 'Die neue Laufzeit muss beim Server ankommen.');
    await abbauen(tester);
  });

  testWidgets('und beenden', (tester) async {
    await zeige(tester);
    await stelleUhr(tester, start);
    await tester.tap(find.textContaining('Bierlaune bis'));
    await tester.pumpAndSettle();

    // Auf der Testflaeche (800x600) liegt der Eintrag unter dem Rand —
    // genau der Fall, fuer den der Zettel scrollbar ist. Vorher schnitt
    // die Spalte hier einfach ab.
    await tester.ensureVisible(find.text('Bierlaune beenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bierlaune beenden'));
    await tester.pumpAndSettle();

    expect(online.aufrufe, contains('setBierlaune:null'));
    await abbauen(tester);
  });
}
