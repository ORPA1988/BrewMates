import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/domain/account_level.dart';

void main() {
  test('Stufen haben Namen, Emoji und Rechte-Liste', () {
    for (final level in [0, 1, 2, 3, 4, 5]) {
      expect(levelName(level), isNotEmpty);
      expect(levelEmoji(level), isNotEmpty);
      expect(levelPerks(level), isNotEmpty);
    }
    expect(levelName(2), 'Stammgast');
    expect(levelName(3), 'Bierkenner');
  });

  test('nextLevelHint zeigt die fehlenden Punkte zur nächsten Stufe', () {
    expect(
      nextLevelHint(const AccountLevelInfo(level: 1, points: 10)),
      contains('noch 15 Punkte'),
    );
    expect(
      nextLevelHint(const AccountLevelInfo(level: 2, points: 40)),
      contains('noch 60 Punkte'),
    );
    // Ab Bierkenner und bei Sperre gibt es nichts mehr zu erreichen.
    expect(nextLevelHint(const AccountLevelInfo(level: 3, points: 150)),
        isNull);
    expect(
        nextLevelHint(const AccountLevelInfo(level: 0, points: 0)), isNull);
  });
}
