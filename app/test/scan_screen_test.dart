// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/scan/scan_screen.dart';

/// Der Scan-Bildschirm ohne Kamera (Backlog B-5).
///
/// **Was hier geprüft wird und was nicht:** Die Kamera selbst braucht ein
/// Gerät — `mobile_scanner` spricht mit einem Plattform-Kanal, den es im
/// Test nicht gibt. Der Bildschirm hat aber einen zweiten, gleichwertigen
/// Weg: die getippte EAN. Den blendet er auf Plattformen ohne Kamera von
/// selbst ein, und `debugDefaultTargetPlatformOverride` erreicht genau
/// diesen Zustand — ohne eine Zeile Produktivcode dafür zu ändern.
///
/// Damit ist der Teil abgedeckt, der Fehler machen kann: die Prüfung der
/// Eingabe. Die Kamera liefert am Ende nur eine Ziffernfolge an dieselbe
/// Stelle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
  });

  Future<void> zeige(WidgetTester tester) async {
    // Ohne Kamera-Plattform baut der Bildschirm den Scanner gar nicht erst
    // — und zeigt stattdessen die Tastatureingabe. Das Zurücksetzen muss
    // INNERHALB des Testkörpers passieren (siehe `abbauen`): Flutter prüft
    // am Ende jedes Tests, dass keine Debug-Variable gesetzt blieb.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: ScanScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('Ohne Kamera bietet der Bildschirm die Tastatureingabe',
      (tester) async {
    await zeige(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('EAN eintippen'), findsOneWidget);
    // Noch keine Fehlermeldung — die Feldbeschriftung nennt die Länge
    // ebenfalls, deshalb wird auf den Meldungstext geprüft, nicht auf
    // „8 oder 13 Ziffern".
    expect(find.textContaining('Ein Barcode hat'), findsNothing);
    await abbauen(tester);
  });

  testWidgets('Zu kurze Eingabe wird verständlich abgelehnt', (tester) async {
    await zeige(tester);

    await tester.enterText(find.byType(TextField), '123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Die Meldung nennt die erwartete Länge UND das, was ankam — ohne
    // beides rät der Mensch, was er falsch gemacht hat.
    expect(find.textContaining('Ein Barcode hat'), findsOneWidget);
    expect(find.textContaining('123 erkannt'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Buchstaben und Trennzeichen stören nicht', (tester) async {
    await zeige(tester);

    // Abgetippte Barcodes enthalten oft Leerzeichen oder Bindestriche.
    // Die Ziffern zählen, der Rest fliegt raus — und 7 Ziffern bleiben zu
    // wenig, also erscheint die Längenmeldung mit der bereinigten Zahl.
    await tester.enterText(find.byType(TextField), '90-034 10a');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('9003410 erkannt'), findsOneWidget);
    await abbauen(tester);
  });

  // Bewusst KEIN Test für die gültige EAN: Der Bildschirm navigiert dann
  // sofort weiter (Bier anlegen bzw. Detailansicht). Das braucht den
  // Router und prüft Funktion 04, nicht den Scanner. Was hier zählt, ist
  // die Eingabeprüfung davor — und die ist oben abgedeckt.
}
