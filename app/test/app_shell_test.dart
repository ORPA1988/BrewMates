import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/location_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/main.dart';

/// Fake-GPS für Widget-Tests: liefert sofort Wien.
class _FakeLocationService extends LocationService {
  const _FakeLocationService();

  @override
  Future<LocationResult> getCurrentPosition() async =>
      const LocationGranted(48.2082, 16.3738);
}

Widget _app() => ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.memory();
          ref.onDispose(db.close);
          return db;
        }),
        locationServiceProvider
            .overrideWithValue(const _FakeLocationService()),
        // Kein Supabase in Widget-Tests: der Offline-Pfad ist der Testpfad.
        onlineServiceProvider.overrideWith((ref) async => null),
      ],
      child: const BrewMatesApp(),
    );

/// Baut den Baum ab und lässt ausstehende Zero-Duration-Timer (Drift-Streams,
/// DB-Close) auslaufen, bevor flutter_test seine Timer-Invariante prüft.
Future<void> _windDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('Home zeigt die zwei Hero-Aktionen – ohne Demo-Daten',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Bier scannen'), findsOneWidget);
    expect(find.text('Zusammenkommen!'), findsOneWidget);
    // Keine Demo-Sessions/-Freunde mehr: die Abschnitte bleiben leer.
    expect(find.text('Gerade unterwegs 🍻'), findsNothing);
    expect(find.textContaining('Anna'), findsNothing);

    await _windDown(tester);
  });

  testWidgets('Entdecken-Tab: Suche findet Biere aus der Datenbank',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entdecken'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Bier, Brauerei oder Gasthaus'),
        'Augustiner');
    await tester.pumpAndSettle();

    expect(find.textContaining('Augustiner'), findsWidgets);

    await _windDown(tester);
  });

  testWidgets('Entdecken vereint Biere, Brauereien und Gasthäuser',
      (tester) async {
    // Die Gasthausliste war vorher ein eigener Bildschirm hinter einem
    // Knopf auf der Karte — man musste wissen, dass es sie gibt.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entdecken'));
    await tester.pumpAndSettle();

    for (final bereich in ['Biere', 'Brauereien', 'Gasthäuser']) {
      expect(find.text(bereich), findsOneWidget,
          reason: '$bereich fehlt im Entdecken-Bildschirm');
    }

    // Der Gasthaus-Bereich bringt die Filter der abgelösten Liste mit.
    await tester.tap(find.text('Gasthäuser'));
    await tester.pumpAndSettle();
    expect(find.textContaining('jetzt geöffnet'), findsOneWidget);

    await _windDown(tester);
  });

  testWidgets('Beacon-Flow: Ein Tap startet die Session, Undo beendet sie',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zusammenkommen!'));
    await tester.pumpAndSettle();

    // Erste eigene Session → „Session-Starter"-Abzeichen wird gefeiert.
    expect(find.textContaining('Session-Starter'), findsWidgets);
    await tester.tap(find.text('Prost! 🍻').last);
    await tester.pumpAndSettle();

    expect(find.text('Beacon läuft!'), findsOneWidget);

    // Undo: Session wieder beenden → zurück auf Home, Hero-Karte ist zurück.
    await tester.tap(find.text('Ups – wieder beenden'));
    await tester.pumpAndSettle();

    expect(find.text('Zusammenkommen!'), findsOneWidget);
    expect(find.text('Dein Beacon läuft'), findsNothing);

    await _windDown(tester);
  });

  testWidgets('Scanner (Desktop-Fallback): EAN aus der Community-DB '
      'zeigt den Treffer und führt zum Check-in', (tester) async {
    // Desktop simulieren: In Widget-Tests meldet defaultTargetPlatform
    // sonst Android und der Screen würde die Kamera-Ansicht rendern.
    // (Reset am Test-Ende im Body — die Binding-Invarianten verlangen das.)
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bier scannen'));
    await tester.pumpAndSettle();

    // Auf dem Test-Host gibt es keine Kamera → manuelles EAN-Feld.
    // 90034107 = Stiegl-Goldbräu aus der gebündelten Österreich-DB
    // (der Scan-Flow wartet selbst auf den Community-Import).
    await tester.enterText(
        find.widgetWithText(TextField, 'EAN eintippen (8 oder 13 Ziffern)'),
        '90034107');
    await tester.tap(find.text('Suchen'));
    await tester.pumpAndSettle();

    // Treffer-Bestätigung (Bottom Sheet) zeigt das erkannte Bier …
    expect(find.text('Gefunden! 🎯'), findsOneWidget);
    expect(find.textContaining('Stiegl-Goldbräu'), findsWidgets);

    // … und „Einchecken" führt zum Check-in mit vorausgewähltem Bier.
    await tester.tap(find.text('Einchecken'));
    await tester.pumpAndSettle();

    expect(find.text('Bier einchecken'), findsOneWidget);
    expect(find.textContaining('Stiegl-Goldbräu'), findsWidgets);

    await _windDown(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Ungültige EAN zeigt eine verständliche Fehlermeldung',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bier scannen'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'EAN eintippen (8 oder 13 Ziffern)'),
        '1234');
    await tester.tap(find.text('Suchen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('8 oder 13 Ziffern'), findsWidgets);

    await _windDown(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Check-in-Flow über Home: suchen, speichern, Abzeichen',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ohne Scannen einchecken'));
    await tester.pumpAndSettle();

    // Bier suchen und auswählen (aus der gebündelten Community-DB).
    await tester.enterText(find.byType(TextField).first, 'Goldbräu');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Stiegl-Goldbräu').first);
    await tester.pumpAndSettle();

    // Zum Speichern-Button scrollen und speichern.
    await tester.scrollUntilVisible(find.text('Speichern'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Erster Check-in → „Erster Schluck"-Abzeichen wird gefeiert.
    expect(find.textContaining('Erster Schluck'), findsWidgets);
    await tester.tap(find.text('Prost! 🍻').last);
    await tester.pumpAndSettle();

    await _windDown(tester);
  });
}
