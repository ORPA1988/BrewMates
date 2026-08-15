import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/format.dart';
import 'package:brewmates/data/providers.dart';

void main() {
  group('Grenzen der Beacon-Laufzeit', () {
    test('Werte innerhalb der Grenzen bleiben unverändert', () {
      for (final d in sessionDurationChoices) {
        expect(clampSessionDuration(d), d);
      }
    });

    test('Zu kurz wird auf die Untergrenze gehoben', () {
      expect(clampSessionDuration(const Duration(minutes: 1)),
          minSessionDuration);
      expect(clampSessionDuration(Duration.zero), minSessionDuration);
    });

    test('Zu lang wird auf die Obergrenze gedeckelt', () {
      // Ein Beacon, der aus Versehen stehen bleibt, zeigt dauerhaft einen
      // Aufenthaltsort — deshalb die harte Obergrenze.
      expect(clampSessionDuration(const Duration(days: 365)),
          maxSessionDuration);
    });

    test('Die Auswahl liegt vollständig innerhalb der Grenzen', () {
      for (final d in sessionDurationChoices) {
        expect(d >= minSessionDuration, isTrue,
            reason: '$d ist kürzer als die Untergrenze');
        expect(d <= maxSessionDuration, isTrue,
            reason: '$d ist länger als die Obergrenze');
      }
    });
  });

  group('formatDuration', () {
    test('Unter einer Stunde in Minuten', () {
      expect(formatDuration(const Duration(minutes: 30)), '30 min');
    });

    test('Eine Stunde im Singular', () {
      expect(formatDuration(const Duration(hours: 1)), '1 Stunde');
    });

    test('Mehrere Stunden im Plural', () {
      expect(formatDuration(const Duration(hours: 5)), '5 Stunden');
      expect(formatDuration(const Duration(hours: 12)), '12 Stunden');
    });

    test('Angebrochene Stunden bekommen die Minuten dazu', () {
      expect(formatDuration(const Duration(hours: 2, minutes: 30)),
          '2 Stunden 30 min');
    });
  });
}
