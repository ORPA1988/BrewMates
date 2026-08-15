import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/theme.dart';

/// Emojis müssen in der App farbig bleiben.
///
/// Vorgeschichte: Die Schriftkette listete das gebündelte **monochrome**
/// `NotoEmoji` unbedingt. Diese Kette wird vor der Systemschrift
/// durchsucht — auf Android gewann also der schwarz-weiße Umriss gegen
/// die farbige Systemschrift, die das Gerät längst mitbringt. Die Web-App
/// sah bunt aus, die App blass, und der Kommentar im Code behauptete
/// bereits das Gegenteil („Android rendert Emojis ohnehin nativ in
/// Farbe").
///
/// Im Widget-Test meldet `defaultTargetPlatform` Android, `kIsWeb` ist
/// false — wir prüfen also genau den App-Fall.
void main() {
  test('Auf dem Gerät steht keine monochrome Emoji-Schrift im Weg', () {
    final fallback =
        BrewTheme.light.textTheme.bodyMedium?.fontFamilyFallback ??
            const <String>[];

    expect(
      fallback.contains('NotoEmoji'),
      isFalse,
      reason: 'Das monochrome Bundle würde vor Androids farbiger '
          'Systemschrift greifen — 🍺 erschiene als blasser Umriss.',
    );
  });

  test('Symbolschrift bleibt, sie ersetzt keine Emojis', () {
    // ● und ○ hat keine Systemschrift zuverlässig; NotoSansSymbols2
    // enthält keine Emojis und steht der Farbdarstellung nicht im Weg.
    final fallback =
        BrewTheme.light.textTheme.bodyMedium?.fontFamilyFallback ??
            const <String>[];
    expect(fallback.contains('NotoSansSymbols2'), isTrue);
  });
}
