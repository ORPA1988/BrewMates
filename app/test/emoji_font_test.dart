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
/// Die Kette hängt an `kIsWeb`, und das lässt sich nicht überschreiben —
/// also braucht jede Seite ihren eigenen Lauf. `testOn` teilt die beiden
/// Fälle auf: Der VM-Lauf prüft das Gerät, der Browser-Lauf das Web.
void main() {
  List<String> fallback() =>
      BrewTheme.light.textTheme.bodyMedium?.fontFamilyFallback ??
      const <String>[];

  test('Auf dem Gerät steht keine monochrome Emoji-Schrift im Weg', () {
    expect(
      fallback().contains('NotoEmoji'),
      isFalse,
      reason: 'Das monochrome Bundle würde vor Androids farbiger '
          'Systemschrift greifen — 🍺 erschiene als blasser Umriss.',
    );
  }, testOn: 'vm');

  test('Im Browser liegt das gebündelte Emoji-Bundle bereit', () {
    // Umgekehrter Fall: Der Browser bringt keine verlässliche
    // Emoji-Schrift mit, deshalb liefert die App sie dort selbst mit —
    // farbig zuerst, monochrom als Rückfall.
    expect(fallback().contains('NotoColorEmoji'), isTrue);
    expect(fallback().contains('NotoEmoji'), isTrue);
  }, testOn: 'browser');

  test('Symbolschrift bleibt, sie ersetzt keine Emojis', () {
    // ● und ○ hat keine Systemschrift zuverlässig; NotoSansSymbols2
    // enthält keine Emojis und steht der Farbdarstellung nicht im Weg.
    final fallback =
        BrewTheme.light.textTheme.bodyMedium?.fontFamilyFallback ??
            const <String>[];
    expect(fallback.contains('NotoSansSymbols2'), isTrue);
  });
}
