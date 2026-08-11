import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/main.dart';

Widget _app() => ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.memory();
          ref.onDispose(db.close);
          return db;
        }),
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
  testWidgets('App startet: Feed zeigt Session-Leiste aus den Seed-Daten',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('BrewMates'), findsOneWidget);
    expect(find.text('Gerade unterwegs 🍻'), findsOneWidget);
    expect(find.textContaining('Anna'), findsWidgets);

    await _windDown(tester);
  });

  testWidgets('Entdecken-Tab: Suche findet Biere aus der Datenbank',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entdecken'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Bier, Brauerei oder Stil suchen …'),
        'Augustiner');
    await tester.pumpAndSettle();

    expect(find.textContaining('Augustiner'), findsWidgets);

    await _windDown(tester);
  });

  testWidgets('Los!-Button öffnet Auswahl mit Session und Check-in',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Los!'));
    await tester.pumpAndSettle();

    expect(find.text('Session starten'), findsOneWidget);
    expect(find.text('Bier einchecken'), findsOneWidget);

    await tester.tap(find.text('Session starten'));
    await tester.pumpAndSettle();

    expect(find.text('🍺 Bier-Zeit!'), findsOneWidget);
    expect(find.text('Nur ich (Stealth)'), findsOneWidget);

    await _windDown(tester);
  });

  testWidgets('Check-in-Flow: Bier suchen, bewerten, speichern – Abzeichen',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Los!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bier einchecken'));
    await tester.pumpAndSettle();

    // Bier suchen und auswählen.
    await tester.enterText(find.byType(TextField).first, 'Asahi');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Asahi Super Dry').first);
    await tester.pumpAndSettle();

    // Zum Speichern-Button scrollen und speichern.
    await tester.scrollUntilVisible(find.text('Speichern'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Erster Check-in → „Erster Schluck"-Abzeichen wird gefeiert.
    expect(find.textContaining('Erster Schluck'), findsWidgets);
    await tester.tap(find.text('Prost! 🍻').last);
    await tester.pumpAndSettle();

    await _windDown(tester);
  });
}
