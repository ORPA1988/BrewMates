import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/min_version.dart';

/// Der Riegel „Update erforderlich".
///
/// Er entscheidet, ob jemand die App noch benutzen darf. Damit ist er die
/// Stelle mit dem schlechtesten Verhältnis von Codezeilen zu Schaden: Ein
/// Fehler hier sperrt **alle** aus, auch die mit aktueller Version.
///
/// Deshalb ist die Grundhaltung „im Zweifel hereinlassen". BrewMates
/// funktioniert ohne Konto und ohne Netz vollständig — wer im Funkloch
/// sitzt, muss einchecken können.
void main() {
  group('Sperren', () {
    test('Ältere Version als gefordert', () {
      expect(
        istUpdatePflicht(appVersion: '0.9.13-beta+17', minVersion: '0.10.2'),
        isTrue,
      );
    });

    test('0.9.9 ist älter als 0.10.0 — nicht neuer', () {
      // Der klassische Stolperstein: Als Text verglichen wäre „9" größer
      // als „10".
      expect(
        istUpdatePflicht(appVersion: '0.9.9', minVersion: '0.10.0'),
        isTrue,
      );
    });
  });

  group('Hereinlassen', () {
    test('Genau die geforderte Version genügt', () {
      expect(
        istUpdatePflicht(appVersion: '0.10.2-beta+20', minVersion: '0.10.2'),
        isFalse,
        reason: 'Die Mindestversion ist die kleinste ERLAUBTE, nicht die '
            'erste verbotene.',
      );
    });

    test('Neuere Version selbstverständlich', () {
      expect(
        istUpdatePflicht(appVersion: '0.11.0', minVersion: '0.10.2'),
        isFalse,
      );
    });

    test('Keine Antwort vom Server sperrt nicht', () {
      // Offline, abgemeldet, Server weg — nichts davon darf die App
      // unbenutzbar machen. Sie ist local-first.
      expect(
        istUpdatePflicht(appVersion: '0.1.0', minVersion: null),
        isFalse,
      );
    });

    test('Leere oder unlesbare Antwort sperrt nicht', () {
      // Ein Tippfehler in einer Konfigurationszeile darf nicht die
      // gesamte Nutzerschaft aussperren.
      for (final murks in ['', '   ', 'bald', 'null', '-']) {
        expect(
          istUpdatePflicht(appVersion: '0.1.0', minVersion: murks),
          isFalse,
          reason: 'Bei „$murks" muss die App weiterlaufen.',
        );
      }
    });

    test('Suffixe und Präfixe stören den Vergleich nicht', () {
      expect(
        istUpdatePflicht(appVersion: '0.10.2-beta+20', minVersion: 'v0.10.2'),
        isFalse,
      );
    });
  });
}
