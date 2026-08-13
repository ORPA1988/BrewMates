import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/external_links.dart';

void main() {
  test('Google-Maps-Deeplink bevorzugt Koordinaten', () {
    final uri = googleMapsSearchUri(lat: 48.2082, lng: 16.3738);
    expect(uri.toString(),
        'https://www.google.com/maps/search/?api=1&query=48.2082,16.3738');
  });

  test('Google-Maps-Deeplink enkodiert Textsuchen', () {
    final uri = googleMapsSearchUri(query: 'Zum Goldenen Fass, Wien');
    expect(uri.toString(), contains('query=Zum%20Goldenen%20Fass'));
    expect(uri.toString(), contains('Wien'));
  });

  test('Korrektur-Issue-Link ist vorbefüllt', () {
    final uri =
        communityIssueUri(subject: 'Stiegl-Goldbräu', body: 'ABV: 4,9 → 5,0');
    expect(uri.host, 'github.com');
    expect(uri.queryParameters['title'], 'Korrektur: Stiegl-Goldbräu');
    expect(uri.queryParameters['body'], contains('ABV'));
  });
}
