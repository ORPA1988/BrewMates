/// Wer etwas sehen darf — für Runden und für Check-ins.
///
/// Liegt in `core/` aus demselben Grund wie [ServingStyle]
/// (`serving_style.dart`): Es ist ein reines Wert-Enum ohne
/// Datenbankbezug, aber solange es in der Datenbankdatei stand, musste
/// jeder, der es braucht, `data/` importieren — auch die Beschriftungen
/// in `core/format.dart`, die von der Datenbank nichts wissen dürfen.
///
/// Gespeichert wird der **Name** (`textEnum` in Drift, Enum `visibility`
/// in Supabase mit denselben drei Werten). Werte deshalb nie umbenennen;
/// neue nur anhängen.
library;

enum SessionVisibility { friends, crew, private }

/// Wie eine Sichtbarkeit heißt — an einer Stelle, damit Check-in,
/// Bearbeiten-Blatt und Konto dieselben Worte benutzen (Funktion 44).
String visibilityLabel(SessionVisibility v) => switch (v) {
      SessionVisibility.friends => 'Freunde',
      SessionVisibility.crew => 'Nur meine Crew',
      SessionVisibility.private => 'Privat',
    };

/// Ein Satz dazu, wer das konkret ist.
///
/// Ohne ihn raten Menschen, und bei Sichtbarkeit ist Raten die falsche
/// Übung. Der Hinweis zu „Nur meine Crew" sagt ausdrücklich, dass die
/// Auswahl **ohne Runde nichts bewirkt** — die Regel am Server verlangt
/// eine Session mit Crew, und eine Sicherheit zu behaupten, die die
/// Datenbank nicht hält, wäre schlimmer als keine Erklärung.
String visibilityHint(SessionVisibility v) => switch (v) {
      SessionVisibility.friends =>
        'Deine Freunde — und wer mit dir in der Runde sitzt.',
      SessionVisibility.crew =>
        'Nur die Crew der Runde. Ohne Runde sieht ihn niemand außer dir.',
      SessionVisibility.private => 'Nur du. Auch Mitrundige nicht.',
    };
