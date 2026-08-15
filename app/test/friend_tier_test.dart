import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/online/online_service.dart';

/// Freundeskreise: Reihenfolge, Abbildung auf die Datenbanknamen und der
/// sichere Rückfall.
void main() {
  test('Die Reihenfolge trägt die Vergleiche', () {
    // Muss zur Reihenfolge des Aufzählungstyps in Migration 0024 passen —
    // dort entscheidet `>= freund` über Beacon und Bierlaune.
    expect(FriendTier.bekannter.index, lessThan(FriendTier.freund.index));
    expect(FriendTier.freund.index, lessThan(FriendTier.buddy.index));
  });

  test('Datenbanknamen stimmen mit dem Aufzählungstyp überein', () {
    expect(FriendTier.bekannter.name_, 'bekannter');
    expect(FriendTier.freund.name_, 'freund');
    expect(FriendTier.buddy.name_, 'buddy');
  });

  test('Hin- und Rückweg über den Datenbanknamen', () {
    for (final t in FriendTier.values) {
      expect(friendTierFromName(t.name_), t);
    }
  });

  test('Unbekanntes fällt auf „Freund" zurück, nicht auf „Bekannter"', () {
    // Der Vorgabewert der Migration ist `freund`. Ein Rückfall nach unten
    // würde bestehenden Freundschaften stillschweigend Sichtbarkeit
    // nehmen — genau das soll die Einführung nicht tun.
    expect(friendTierFromName(null), FriendTier.freund);
    expect(friendTierFromName(''), FriendTier.freund);
    expect(friendTierFromName('quatsch'), FriendTier.freund);
  });

  test('Neue Profile starten als Freund', () {
    final p = RemoteProfile.fromRow(const {
      'id': 'x',
      'username': 'mate',
      'display_name': 'Mate',
      'avatar_emoji': '🍺',
    });
    expect(p.tier, FriendTier.freund);
  });

  test('Der Kreis kommt aus der Zeile, nicht aus dem Profil', () {
    final p = RemoteProfile.fromRow(const {
      'id': 'x',
      'username': 'mate',
      'display_name': 'Mate',
      'avatar_emoji': '🍺',
    }, tier: FriendTier.bekannter);
    expect(p.tier, FriendTier.bekannter);
  });

  test('Jeder Kreis hat Beschriftung, Emoji und Erklärung', () {
    for (final t in FriendTier.values) {
      expect(t.label, isNotEmpty);
      expect(t.emoji, isNotEmpty);
      expect(t.description, isNotEmpty);
    }
  });

  test('Bierlaune gilt nur, solange sie nicht abgelaufen ist', () {
    RemoteProfile withThirst(DateTime? until) => RemoteProfile(
          id: 'x',
          username: 'mate',
          displayName: 'Mate',
          avatarEmoji: '🍺',
          thirstyUntil: until,
        );

    expect(withThirst(null).hasBierlaune, isFalse);
    expect(
        withThirst(DateTime.now().subtract(const Duration(hours: 1)))
            .hasBierlaune,
        isFalse);
    expect(
        withThirst(DateTime.now().add(const Duration(hours: 1))).hasBierlaune,
        isTrue);
  });
}
