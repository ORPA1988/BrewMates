import 'browserfenster.dart';

/// Überall außer im Browser: Das Fenster gilt als sichtbar, und
/// Systemmeldungen gibt es nicht.
///
/// Damit bleibt auf Android, Windows und in Tests alles, wie es war — die
/// Hülle zeigt weiter ihre Snackbar, weil [sichtbar] immer `true` meldet.
class BrowserfensterImpl implements Browserfenster {
  @override
  bool get imBrowser => false;

  @override
  bool get benachrichtigungenMoeglich => false;

  /// Eine Android-App ist keine installierte Web-App. Die Frage ergibt
  /// hier keinen Sinn, und `false` ist die harmlose Antwort: Zusammen mit
  /// [imBrowser] `false` zeigt die Startseite ohnehin keinen Hinweis.
  @override
  bool get alsAppInstalliert => false;

  @override
  bool hinweisWeggewischt(String schluessel) => false;

  @override
  void hinweisWegwischen(String schluessel) {}

  @override
  String get erlaubnis => Browserfenster.nichtVerfuegbar;

  @override
  Future<String> erlaubnisAnfragen() async => Browserfenster.nichtVerfuegbar;

  @override
  bool get sichtbar => true;

  @override
  Stream<bool> get sichtbarkeit => const Stream.empty();

  @override
  void zeige({
    required String text,
    String? tag,
    void Function()? beiKlick,
  }) {}
}
