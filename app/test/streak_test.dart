import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/domain/streak.dart';

void main() {
  // 2026-08-14 ist ein Freitag; Wochenstart Montag 2026-08-10.
  final now = DateTime(2026, 8, 14, 20);

  test('Keine Check-ins → keine Serie', () {
    expect(weeklyStreak(const [], now), 0);
  });

  test('Drei Wochen in Folge zählen als 3', () {
    final dates = [
      DateTime(2026, 8, 12), // diese Woche
      DateTime(2026, 8, 5), // Vorwoche
      DateTime(2026, 7, 29), // Woche davor
    ];
    expect(weeklyStreak(dates, now), 3);
  });

  test('Lücke bricht die Serie', () {
    final dates = [
      DateTime(2026, 8, 12), // diese Woche
      DateTime(2026, 7, 22), // 3 Wochen davor — Lücke dazwischen
    ];
    expect(weeklyStreak(dates, now), 1);
  });

  test('Laufende Woche ohne Check-in bricht die Serie noch nicht', () {
    final dates = [
      DateTime(2026, 8, 7), // Vorwoche (Fr)
      DateTime(2026, 7, 30), // Woche davor
    ];
    expect(weeklyStreak(dates, now), 2);
  });

  test('Serie komplett abgerissen (letzter Check-in vor 2 Wochen)', () {
    expect(weeklyStreak([DateTime(2026, 7, 28)], now), 0);
  });

  test('Mehrere Check-ins in derselben Woche zählen einfach', () {
    final dates = [
      DateTime(2026, 8, 10),
      DateTime(2026, 8, 11),
      DateTime(2026, 8, 13),
    ];
    expect(weeklyStreak(dates, now), 1);
  });
}
