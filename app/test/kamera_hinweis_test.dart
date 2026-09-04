import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart'
    show MobileScannerErrorCode, MobileScannerException;

import 'package:brewmates/widgets/kamera_hinweis.dart';

/// Was passiert, wenn die Kamera nicht liefert (Roadmap-Punkt
/// „Kamera-Hinweise beim Scannen", Issue #64).
///
/// Die Kamera selbst ist im Test nicht zu haben — der Plattform-Kanal
/// fehlt. Prüfbar ist aber genau der Teil, der vorher gefehlt hat: dass
/// aus einem Fehlercode ein Satz wird, den ein Mensch versteht, und dass
/// der Ausweg immer mitgenannt wird.
void main() {
  group('Fehlercode → Problem', () {
    test('fehlende Berechtigung ist ein eigener Fall', () {
      expect(kameraProblemFuer(MobileScannerErrorCode.permissionDenied),
          KameraProblem.verweigert);
    });

    test('nicht unterstützt ist ein eigener Fall', () {
      expect(kameraProblemFuer(MobileScannerErrorCode.unsupported),
          KameraProblem.nichtVerfuegbar);
    });

    test('Programmierfehler landen nicht als eigene Nutzermeldung', () {
      // Wer liest, dass der Controller schon initialisiert sei, kann
      // nichts tun. Solche Codes gehören in denselben Topf wie ein
      // beliebiger Gerätefehler.
      for (final code in [
        MobileScannerErrorCode.controllerAlreadyInitialized,
        MobileScannerErrorCode.controllerDisposed,
        MobileScannerErrorCode.controllerUninitialized,
        MobileScannerErrorCode.genericError,
      ]) {
        expect(kameraProblemFuer(code), KameraProblem.unbekannt,
            reason: '$code');
      }
    });
  });

  group('Erklärung', () {
    test('nennt im Browser das Schloss, sonst die App-Einstellungen', () {
      final browser = kameraErklaerung(KameraProblem.verweigert,
          imBrowser: true);
      final geraet = kameraErklaerung(KameraProblem.verweigert,
          imBrowser: false);
      expect(browser, contains('Schloss'));
      expect(browser, isNot(contains('App-Einstellungen')));
      expect(geraet, contains('App-Einstellungen'));
      expect(geraet, isNot(contains('Schloss')));
    });

    test('jeder Fall hat einen ganzen Satz, kein Fachwort', () {
      for (final problem in KameraProblem.values) {
        for (final imBrowser in [true, false]) {
          final text = kameraErklaerung(problem, imBrowser: imBrowser);
          expect(text.trim(), isNotEmpty);
          expect(text.trim(), endsWith('.'));
          expect(text.toLowerCase(), isNot(contains('error')));
          expect(text.toLowerCase(), isNot(contains('exception')));
          expect(kameraTitel(problem).trim(), isNotEmpty);
        }
      }
    });
  });

  group('Der Hinweis auf dem Bildschirm', () {
    Future<void> zeige(
      WidgetTester tester, {
      required MobileScannerErrorCode code,
      required String ausweg,
      bool imBrowser = false,
      Future<bool> Function()? einstellungen,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: KameraHinweis.ausFehler(
            MobileScannerException(errorCode: code),
            ausweg: ausweg,
            imBrowser: imBrowser,
            einstellungenOeffnen: einstellungen,
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('erklärt und nennt den zweiten Weg', (tester) async {
      await zeige(
        tester,
        code: MobileScannerErrorCode.permissionDenied,
        ausweg: 'Der Barcode geht auch getippt.',
      );
      expect(find.text('Kamera ist nicht freigegeben'), findsOneWidget);
      expect(find.textContaining('App-Einstellungen'), findsOneWidget);
      // Das Entscheidende: Der Mensch bleibt nicht stehen.
      expect(find.text('Der Barcode geht auch getippt.'), findsOneWidget);
    });

    // Nur auf der VM: `_einstellungenMoeglich` fragt neben `imBrowser`
    // auch `kIsWeb` ab, und das lässt sich nicht überschreiben. Im
    // Browser-Lauf gäbe es den Knopf also nie — und das ist richtig so,
    // dort führte er ins Leere. Der Fall darunter prüft genau das.
    if (!kIsWeb) {
      testWidgets('der Einstellungs-Knopf führt in die App-Einstellungen',
          (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        var geoeffnet = false;
        await zeige(
          tester,
          code: MobileScannerErrorCode.permissionDenied,
          ausweg: 'Tipp den Barcode ein.',
          einstellungen: () async {
            geoeffnet = true;
            return true;
          },
        );
        await tester.tap(find.text('Einstellungen öffnen'));
        await tester.pump();
        expect(geoeffnet, isTrue);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('kein Einstellungs-Knopf, wo er nirgends hinführt',
        (tester) async {
      // Im Browser gibt es keine App-Einstellungsseite — dort wäre der
      // Knopf eine Sackgasse. Die Erklärung nennt stattdessen das
      // Schloss-Symbol.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await zeige(
        tester,
        code: MobileScannerErrorCode.permissionDenied,
        ausweg: 'Tipp den Barcode ein.',
        imBrowser: true,
      );
      expect(find.text('Einstellungen öffnen'), findsNothing);
      expect(find.textContaining('Schloss'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('kein Einstellungs-Knopf, wenn die Berechtigung nicht das '
        'Problem ist', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await zeige(
        tester,
        code: MobileScannerErrorCode.unsupported,
        ausweg: 'Tipp den Barcode ein.',
      );
      expect(find.text('Einstellungen öffnen'), findsNothing);
      expect(find.text('Kein Kamera-Scan möglich'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
