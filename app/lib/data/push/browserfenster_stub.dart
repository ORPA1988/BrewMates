import 'browserfenster.dart';

/// Überall außer im Browser: Das Fenster gilt als sichtbar, und
/// Systemmeldungen gibt es nicht.
///
/// Damit bleibt auf Android, Windows und in Tests alles, wie es war — die
/// Hülle zeigt weiter ihre Snackbar, weil [sichtbar] immer `true` meldet.
class BrowserfensterImpl implements Browserfenster {
  @override
  bool get benachrichtigungenMoeglich => false;

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
