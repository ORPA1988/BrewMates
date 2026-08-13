import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brewmates/core/app_update.dart';

void main() {
  test('compareAppVersions vergleicht numerisch und ignoriert Suffixe', () {
    expect(compareAppVersions('v0.9.7-beta', '0.9.6-beta+10'), greaterThan(0));
    expect(compareAppVersions('0.10.0', '0.9.9'), greaterThan(0));
    expect(compareAppVersions('v0.9.6-beta', '0.9.6-beta+10'), 0);
    expect(compareAppVersions('1.0.0', 'v1.0'), 0);
    expect(compareAppVersions('0.9.5', '0.9.6'), lessThan(0));
  });

  MockClient releaseClient(Map<String, dynamic> payload) =>
      MockClient((_) async => http.Response.bytes(
          utf8.encode(json.encode(payload)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));

  test('checkForUpdate meldet neueres Release mit APK-Link', () async {
    final client = releaseClient({
      'tag_name': 'v0.9.7-beta',
      'body': 'Neue Gasthausliste 🍽',
      'assets': [
        {
          'name': 'brewmates-v0.9.7-beta.aab',
          'browser_download_url': 'https://example.com/x.aab',
        },
        {
          'name': 'brewmates-v0.9.7-beta.apk',
          'browser_download_url': 'https://example.com/x.apk',
        },
      ],
    });
    final update =
        await checkForUpdate(client, currentVersion: '0.9.6-beta+10');
    expect(update, isNotNull);
    expect(update!.version, 'v0.9.7-beta');
    expect(update.apkUrl, 'https://example.com/x.apk');
    expect(update.notes, contains('Gasthausliste'));
  });

  test('checkForUpdate schweigt bei aktueller Version und bei Fehlern',
      () async {
    final current = releaseClient({
      'tag_name': 'v0.9.6-beta',
      'assets': [
        {
          'name': 'a.apk',
          'browser_download_url': 'https://example.com/a.apk'
        },
      ],
    });
    expect(await checkForUpdate(current, currentVersion: '0.9.6-beta+10'),
        isNull);

    final broken = MockClient((_) async => http.Response('kaputt', 200));
    expect(await checkForUpdate(broken, currentVersion: '0.9.6-beta+10'),
        isNull);

    final rateLimited = MockClient((_) async => http.Response('{}', 403));
    expect(
        await checkForUpdate(rateLimited, currentVersion: '0.9.6-beta+10'),
        isNull);
  });
}
