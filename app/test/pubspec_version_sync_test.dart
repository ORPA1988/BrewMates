// Wächter über Dateien im Repo: liest sie mit `dart:io`. Ein Browser
// hat kein Dateisystem, und geprüft wird hier ohnehin das Repo und
// nicht die App. Siehe docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/config.dart';

void main() {
  test('AppConfig.appVersion stimmt mit pubspec.yaml überein', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml ohne version-Zeile?');
    expect(
      AppConfig.appVersion,
      match!.group(1),
      reason: 'Beim Versions-Bump BEIDE Stellen pflegen: pubspec.yaml und '
          'AppConfig.appVersion (Grundlage des Update-Checks).',
    );
  });
}
