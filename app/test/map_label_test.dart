import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/features/map/map_screen.dart' show activeUsersLabel;

/// Das Karten-Wording ist laut `CLAUDE.md` bewusst an **einer** Stelle
/// gebündelt: `activeUsersLabel()`.
///
/// Der Grund ist keine Ästhetik. Der Satz ist das Versprechen, das die
/// Karte Fremden gegenüber gibt — sie werden **gezählt**, nicht verortet.
/// Wer ihn umformuliert, ändert eine Datenschutzaussage. Ein Test hält
/// fest, dass dabei das Zählwort stimmt und niemand versehentlich aus
/// „aktiv" ein „in der Nähe" macht.
void main() {
  test('Einzahl und Mehrzahl stimmen', () {
    expect(activeUsersLabel(1), '🍻 1 weiterer BrewMate aktiv');
    expect(activeUsersLabel(2), '🍻 2 weitere BrewMates aktiv');
    expect(activeUsersLabel(0), '🍻 0 weitere BrewMates aktiv');
  });

  test('Der Text sagt „aktiv", nicht „in der Nähe"', () {
    // „In der Nähe" wäre eine Ortsangabe — genau das, was Nicht-Freunden
    // gegenüber nicht behauptet werden darf.
    for (final n in [0, 1, 5, 42]) {
      final text = activeUsersLabel(n);
      expect(text, contains('aktiv'));
      expect(text.toLowerCase(), isNot(contains('nähe')));
      expect(text.toLowerCase(), isNot(contains('hier')));
      expect(text, contains('$n'));
    }
  });
}
