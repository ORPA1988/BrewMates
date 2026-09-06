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

  /// Läuft die App überhaupt in einem Browser?
  ///
  /// Die stumme Fassung sagt `false`. Ohne diese Frage ließe sich
  /// „iPhone-Safari, wo es `Notification` nicht gibt" nicht von „Android-App,
  /// wo es die Klasse gar nicht braucht" unterscheiden — beide melden
  /// sonst dasselbe, brauchen aber entgegengesetzte Hinweise.
  bool get imBrowser;

  /// Kennt dieser Browser überhaupt Benachrichtigungen?
  ///
  /// Auf dem iPhone lautet die Antwort außerhalb einer installierten
  /// Web-App **nein** — Safari stellt `Notification` dort nicht bereit.
  /// Das ist keine Einstellung, die jemand ändern könnte.
  bool get benachrichtigungenMoeglich;

  /// Läuft die Seite als installierte Web-App statt in einem Tab?
  ///
  /// Auf dem iPhone ist das der Unterschied, an dem alles hängt: Erst die
  /// Installation über „Zum Home-Bildschirm" stellt `Notification`
  /// überhaupt bereit. Ist sie schon geschehen und fehlt die Klasse
  /// trotzdem, hilft kein Hinweis mehr — dann ist zu schweigen.

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

  bool get alsAppInstalliert;

  /// Hat der Mensch diesen Hinweis schon weggewischt?
  ///
  /// Liegt im Speicher des Browsers und **überlebt das Neuladen** —
  /// anders als der Update-Hinweis auf der Startseite, der nur bis zum
  /// nächsten Start verschwindet. Der Unterschied ist Absicht: Wer sich
  /// gegen das Installieren entschieden hat, soll nicht bei jedem Öffnen
  /// erneut gefragt werden.
  ///
  /// Außerhalb des Browsers immer `false` — dort gibt es die Hinweise
  /// nicht, also auch nichts zu merken.
  bool hinweisWeggewischt(String schluessel);

  /// Merkt sich, dass dieser Hinweis erledigt ist. Scheitert das (privates
  /// Fenster, gesperrter Speicher), ist das kein Fehler: Dann kommt der
  /// Hinweis eben wieder.
  void hinweisWegwischen(String schluessel);

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
