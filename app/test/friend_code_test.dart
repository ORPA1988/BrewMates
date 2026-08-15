import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/features/friends/friend_code.dart';

void main() {
  const id = '3f2a91c4-5b6d-4e7f-8a90-1b2c3d4e5f60';

  test('Bauen und Lesen ergeben wieder dieselbe ID', () {
    expect(parseFriendCode(buildFriendCode(id)), id);
  });

  test('Fremde Codes werden nicht als Freundesanfrage missverstanden', () {
    // Genau dafür gibt es das Präfix: WLAN-Zugänge, Speisekarten und
    // Paketaufkleber sind auch QR-Codes.
    for (final foreign in [
      'https://example.org',
      'WIFI:S=Gasthaus;T=WPA;P=bier;;',
      id, // nackte UUID ohne Präfix
      'brewmates:venue:$id',
      'BREWMATES:FRIEND:$id', // Groß/Klein zählt
    ]) {
      expect(parseFriendCode(foreign), isNull, reason: foreign);
    }
  });

  test('Leere und verstümmelte Codes ergeben null', () {
    expect(parseFriendCode(null), isNull);
    expect(parseFriendCode(''), isNull);
    expect(parseFriendCode('brewmates:friend:'), isNull);
    expect(parseFriendCode('brewmates:friend:   '), isNull);
  });

  test('Whitespace am Rand wird verziehen', () {
    // Manche Scanner hängen Zeilenumbrüche an.
    expect(parseFriendCode('  ${buildFriendCode(id)}\n'), id);
  });
}
