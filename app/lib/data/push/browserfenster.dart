import 'browserfenster_stub.dart'
    if (dart.library.js_interop) 'browserfenster_web.dart' as impl;

/// Was der Browser über sein eigenes Fenster verrät — und was er anzeigen
/// darf, während BrewMates in einem anderen Tab liegt.
///
/// **Warum es das gibt.** Im Browser kommt eine Benachrichtigung längst
/// an: Realtime liefert die Zeile aus `notifications` in Sekunden
/// ([NotificationsApi.incoming]). Gesehen wird sie trotzdem nur, wenn der
/// Tab gerade vorn ist — die Snackbar in der Hülle ist nach ein paar
/// Sekunden weg und der Mensch war woanders.
///
/// Diese Schnittstelle schließt genau diese Lücke, und nur sie: **solange
/// die Web-App offen ist.** Ist der Tab zu, passiert nichts; dafür bräuchte
/// es echten Web-Push mit Service Worker, und der scheitert an der Adresse
/// (siehe `docs/features/38-benachrichtigungen-im-browser.md`).
///
/// Auf Android, Windows und in Tests antwortet die stumme Fassung: Das
/// Fenster gilt als sichtbar, Benachrichtigungen gibt es keine. Damit
/// bleibt das Verhalten dort **exakt** wie bisher.
abstract class Browserfenster {
  /// Die echte Fassung im Browser, sonst die stumme.
  factory Browserfenster() = impl.BrowserfensterImpl;

  /// Kennt dieser Browser überhaupt Benachrichtigungen?
  ///
  /// Auf dem iPhone lautet die Antwort außerhalb einer installierten
  /// Web-App **nein** — Safari stellt `Notification` dort nicht bereit.
  /// Das ist keine Einstellung, die jemand ändern könnte.
  bool get benachrichtigungenMoeglich;

  /// `default` (noch nicht gefragt), `granted`, `denied` — oder
  /// [nichtVerfuegbar], wo es die Sache gar nicht gibt.
  String get erlaubnis;

  static const nichtVerfuegbar = 'nicht-verfuegbar';

  /// Fragt den Menschen. Muss aus einer echten Geste heraus passieren
  /// (Knopfdruck): Firefox verlangt das seit Version 72, Chrome ignoriert
  /// ungefragte Anfragen zunehmend. Deshalb steht der Knopf im Konto und
  /// wird nicht beim Start ausgelöst.
  Future<String> erlaubnisAnfragen();

  /// Liegt das Fenster gerade vorn?
  bool get sichtbar;

  /// Wechsel zwischen Vordergrund und Hintergrund.
  Stream<bool> get sichtbarkeit;

  /// Zeigt eine Systemmeldung. Tut nichts, wenn die Erlaubnis fehlt.
  ///
  /// [tag] ersetzt eine gleichnamige ältere Meldung, statt eine zweite zu
  /// stapeln — sonst hätte man nach zehn Minuten Hintergrund zehn
  /// Kästchen übereinander.
  void zeige({
    required String text,
    String? tag,
    void Function()? beiKlick,
  });
}
