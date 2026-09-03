import 'dart:async';
import 'dart:js_interop';
// Nur für die Merkmalsprüfung: `has` gibt es typisiert nicht, und genau
// hier ist die Frage berechtigt — auf dem iPhone fehlt `Notification`
// außerhalb einer installierten Web-App vollständig.
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'browserfenster.dart';

/// Die Browser-Fassung: Systemmeldungen über die `Notification`-API des
/// Fensters — **ohne** Service Worker und ohne Push-Dienst.
///
/// Das ist der ganze Trick und der Grund, warum das hier überhaupt geht:
/// Eine Meldung, die die geöffnete Seite selbst erzeugt, braucht keinen
/// Service Worker an einem festen Pfad. Genau daran scheitert der Weg
/// über Firebase (siehe `docs/features/38-benachrichtigungen-im-browser.md`)
/// — und genau deshalb ist er hier nicht nötig.
///
/// Was das kostet: Ist der Tab zu, kommt nichts. Das ist die bewusste
/// Grenze dieser Lösung, nicht ein Versehen.
class BrowserfensterImpl implements Browserfenster {
  /// `Notification` gibt es nicht überall. Auf dem iPhone fehlt die
  /// Klasse außerhalb einer installierten Web-App vollständig — ein
  /// Zugriff darauf wirft, statt `denied` zu melden. Deshalb wird das
  /// Vorhandensein geprüft und nicht der Aufruf versucht.
  @override
  bool get benachrichtigungenMoeglich =>
      globalContext.has('Notification');

  @override
  String get erlaubnis => benachrichtigungenMoeglich
      ? web.Notification.permission
      : Browserfenster.nichtVerfuegbar;

  @override
  Future<String> erlaubnisAnfragen() async {
    if (!benachrichtigungenMoeglich) return Browserfenster.nichtVerfuegbar;
    try {
      final antwort = await web.Notification.requestPermission().toDart;
      return antwort.toDart;
    } catch (_) {
      // Manche Browser werfen, wenn die Anfrage nicht aus einer Geste
      // kommt. Dann gilt der Stand von vorher — nicht „abgelehnt".
      return web.Notification.permission;
    }
  }

  @override
  bool get sichtbar => !web.document.hidden;

  @override
  Stream<bool> get sichtbarkeit {
    final controller = StreamController<bool>.broadcast();
    void beiWechsel(web.Event _) {
      if (!controller.isClosed) controller.add(!web.document.hidden);
    }

    final hoerer = beiWechsel.toJS;
    web.document.addEventListener('visibilitychange', hoerer);
    controller.onCancel =
        () => web.document.removeEventListener('visibilitychange', hoerer);
    return controller.stream;
  }

  @override
  void zeige({
    required String text,
    String? tag,
    void Function()? beiKlick,
  }) {
    if (erlaubnis != 'granted') return;
    try {
      final meldung = web.Notification(
        'BrewMates',
        web.NotificationOptions(
          body: text,
          // Ersetzt eine gleichnamige ältere Meldung, statt zu stapeln.
          tag: tag ?? 'brewmates',
          icon: 'icons/Icon-192.png',
        ),
      );
      meldung.onclick = ((web.Event _) {
        // Erst das Fenster nach vorn, dann die Meldung schließen — sonst
        // ist sie weg, bevor der Browser den Fokuswechsel erledigt hat.
        web.window.focus();
        meldung.close();
        beiKlick?.call();
      }).toJS;
    } catch (_) {
      // Eine gescheiterte Systemmeldung darf nichts weiter kosten: Der
      // Inhalt liegt ohnehin in der App, sobald jemand hinsieht.
    }
  }
}
