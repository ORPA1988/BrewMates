import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/domain/opening_hours.dart';

void main() {
  // Mo–Fr 11–24, Sa 10–02 (über Mitternacht), So Ruhetag.
  final week = [
    for (var d = 1; d <= 5; d++)
      OpeningInterval(weekday: d, from: 11 * 60, to: 24 * 60),
    const OpeningInterval(weekday: 6, from: 10 * 60, to: 2 * 60),
  ];

  test('parse/encode-Roundtrip und Sortierung', () {
    final json = jsonEncode(encodeOpeningHours(week));
    final parsed = parseOpeningHours(json);
    expect(parsed, week);

    // Auch bereits dekodierte Listen (PostgREST) werden verstanden.
    expect(parseOpeningHours(encodeOpeningHours(week)), week);

    // Unsortierte Eingabe wird nach Tag+Beginn sortiert.
    final shuffled = parseOpeningHours(jsonEncode([
      {'d': 3, 'von': '11:00', 'bis': '24:00'},
      {'d': 1, 'von': '17:00', 'bis': '23:00'},
      {'d': 1, 'von': '11:00', 'bis': '14:00'},
    ]));
    expect(shuffled.map((i) => (i.weekday, i.from)).toList(),
        [(1, 660), (1, 1020), (3, 660)]);
  });

  test('Kaputtes JSON und ungültige Einträge werden ignoriert', () {
    expect(parseOpeningHours(null), isEmpty);
    expect(parseOpeningHours(''), isEmpty);
    expect(parseOpeningHours('kein json'), isEmpty);
    expect(parseOpeningHours('{"d":1}'), isEmpty); // keine Liste
    expect(
        parseOpeningHours(jsonEncode([
          {'d': 0, 'von': '11:00', 'bis': '20:00'}, // Tag ungültig
          {'d': 2, 'von': '25:00', 'bis': '20:00'}, // Stunde ungültig
          {'d': 2, 'von': '11:00'}, // bis fehlt
          {'d': 4, 'von': '11:00', 'bis': '20:00'}, // gültig
        ])),
        [const OpeningInterval(weekday: 4, from: 660, to: 1200)]);
  });

  test('formatOpeningHours fasst gleiche Tage zusammen', () {
    expect(formatOpeningHours(week), 'Mo–Fr 11–24, Sa 10–2, So Ruhetag');
    expect(formatOpeningHours(const []), '');
    expect(
        formatOpeningHours(const [
          OpeningInterval(weekday: 7, from: 630, to: 14 * 60),
        ]),
        'Mo–Sa Ruhetag, So 10:30–14');
  });

  test('isOpenAt: innerhalb, außerhalb, Ruhetag', () {
    // Mi 2026-08-12 ist ein Mittwoch.
    expect(isOpenAt(week, DateTime(2026, 8, 12, 12, 0)), isTrue);
    expect(isOpenAt(week, DateTime(2026, 8, 12, 10, 59)), isFalse);
    expect(isOpenAt(week, DateTime(2026, 8, 16, 12, 0)), isFalse); // So
    expect(isOpenAt(const [], DateTime(2026, 8, 12, 12, 0)), isFalse);
  });

  test('isOpenAt über Mitternacht: Sa 10–02 gilt bis So 01:59', () {
    expect(isOpenAt(week, DateTime(2026, 8, 15, 23, 30)), isTrue); // Sa spät
    expect(isOpenAt(week, DateTime(2026, 8, 16, 1, 30)), isTrue); // So früh
    expect(isOpenAt(week, DateTime(2026, 8, 16, 2, 0)), isFalse);
    expect(isOpenAt(week, DateTime(2026, 8, 15, 9, 59)), isFalse);
  });

  test('nextOpening findet den nächsten Beginn – auch über die Woche', () {
    // So 12:00 → nächster Beginn Mo 11:00.
    expect(nextOpening(week, DateTime(2026, 8, 16, 12, 0)),
        DateTime(2026, 8, 17, 11, 0));
    // Mi 09:00 → noch am selben Tag 11:00.
    expect(nextOpening(week, DateTime(2026, 8, 12, 9, 0)),
        DateTime(2026, 8, 12, 11, 0));
    expect(nextOpening(const [], DateTime(2026, 8, 12, 9, 0)), isNull);
  });

  test('openingStatus liefert die UI-Zeile', () {
    final open = openingStatus(week, DateTime(2026, 8, 12, 12, 0))!;
    expect(open.open, isTrue);
    expect(open.label, '● Jetzt geöffnet · bis 24:00');

    final closed = openingStatus(week, DateTime(2026, 8, 16, 12, 0))!;
    expect(closed.open, isFalse);
    expect(closed.label, '○ Geschlossen · öffnet Mo 11:00');

    final sameDay = openingStatus(week, DateTime(2026, 8, 12, 9, 0))!;
    expect(sameDay.label, '○ Geschlossen · öffnet heute 11:00');

    expect(openingStatus(const [], DateTime(2026, 8, 12, 9, 0)), isNull);
  });
}
