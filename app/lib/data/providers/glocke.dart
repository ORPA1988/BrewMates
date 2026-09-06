part of '../providers.dart';

/// Neue Benachrichtigungen, live vom Server.
///
/// Der Stream tut zwei Dinge, sobald eine Zeile ankommt:
///
/// 1. Er **entwertet** die betroffenen Provider. Anfrage, Annahme —
///    beides aendert Listen, die sonst erst im 30-Sekunden-Takt nachzoegen.
///    Damit sind Startseiten-Karte und Zahl am Profil-Tab sofort aktuell.
/// 2. Er reicht die Zeile weiter, damit die Oberflaeche ein Banner zeigen
///    kann („Clara moechte dein BrewMate sein").
///
/// Faellt Realtime aus, passiert nichts Schlimmes: Der Takt laedt weiter,
/// nur eben nicht sofort. Nichts in der App **haengt** an diesem Stream.
final incomingNotificationsProvider =
    StreamProvider<RemoteNotification>((ref) async* {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return;

  await for (final n in online.notifications.incoming()) {
    switch (n.type) {
      case 'friend_request':
        ref.invalidate(friendRequestsProvider);
      case 'friend_accepted':
        ref.invalidate(outgoingRequestsProvider);
        ref.invalidate(onlineFriendsProvider);
      default:
        break;
    }
    yield n;
  }
});

/// Ungelesener Bestand der Glocke — was beim Start schon da war.
final unreadNotificationsProvider =
    FutureProvider<List<RemoteNotification>>((ref) async {
  ref.watch(onlineUserProvider);
  ref.watch(clockProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.notifications.unread();
});

// ============================================================================
// Im Browser sichtbar werden, solange die Web-App offen ist
// ============================================================================

/// Das Fenster, in dem die App läuft. Im Browser die echte Fassung,
/// überall sonst (und in Tests) die stumme.
final browserfensterProvider =
    Provider<Browserfenster>((ref) => Browserfenster());

/// Liegt die App gerade vorn? Außerhalb des Browsers immer `true`.
final seiteSichtbarProvider = StreamProvider<bool>((ref) async* {
  final fenster = ref.watch(browserfensterProvider);
  // Der erste Wert muss sofort kommen: Wer erst auf den nächsten Wechsel
  // wartet, weiß beim ersten Eintreffen einer Meldung noch nichts.
  yield fenster.sichtbar;
  yield* fenster.sichtbarkeit;
});

/// Meldungen, die eintrafen, während die Seite im Hintergrund lag — und
/// die der Browser nicht als Systemmeldung zeigen durfte.
///
/// **Wozu das nötig ist.** Der Fall trifft genau die Leute, um die es
/// geht: Auf dem iPhone gibt es außerhalb einer installierten Web-App gar
/// keine Systemmeldungen, und wer die Erlaubnis nicht erteilt hat, hat
/// auch keine. Ohne diese Liste wäre die Meldung dann einfach weg — die
/// Snackbar lief ins Leere, während der Tab hinten lag.
///
/// Bewusst nur im Speicher und bewusst ohne Obergrenze in der Zeit: Es
/// geht um „was habe ich verpasst, während ich weg war", nicht um eine
/// Glocke mit Verlauf. Ein Neuladen der Seite leert sie; der Bestand
/// steht dann in [unreadNotificationsProvider].
class VerpassteMeldungen extends Notifier<List<RemoteNotification>> {
  @override
  List<RemoteNotification> build() => const [];

  void merken(RemoteNotification n) => state = [...state, n];

  /// Gibt das Gemerkte zurück und leert es — der Aufrufer zeigt es an.
  List<RemoteNotification> abholen() {
    final alle = state;
    state = const [];
    return alle;
  }
}

final verpassteMeldungenProvider =
    NotifierProvider<VerpassteMeldungen, List<RemoteNotification>>(
        VerpassteMeldungen.new);

// ============================================================================
// Der Hinweis, der auf die zwei Browser-Knöpfe zeigt (Funktion 38)
// ============================================================================

/// Was die Startseite im Browser anbieten soll — falls überhaupt etwas.
enum WebHinweis {
  /// Nichts zu sagen: keine Web-App, schon erlaubt, schon abgelehnt,
  /// schon installiert oder weggewischt.
  keiner,

  /// `Notification` fehlt und die Seite läuft in einem Tab. Das ist der
  /// iPhone-Fall: Erst „Zum Home-Bildschirm" schaltet Meldungen frei.
  installieren,

  /// Der Browser könnte Meldungen zeigen, wurde aber noch nie gefragt.
  erlauben,
}

/// Der Schlüssel, unter dem ein weggewischter Hinweis im Browser liegt.
String webHinweisSchluessel(WebHinweis hinweis) => hinweis.name;

/// Entscheidet, welcher Hinweis dran ist.
///
/// **Warum das überhaupt nötig ist.** Beide Knöpfe gibt es längst — der
/// Erlaubnis-Knopf steht im Konto, und installieren lässt sich die Web-App
/// über das Browsermenü. Nur wusste das niemand: Wer die Seite auf dem
/// iPhone öffnet, sieht nirgends, dass Meldungen an einer Installation
/// hängen, und wer sie am Rechner öffnet, findet den Knopf nur, wenn er
/// im Konto danach sucht.
///
/// **Warum der Hinweis nicht selbst fragt.** Die Erlaubnis muss aus einer
/// echten Geste kommen (Firefox seit Version 72, Chrome zunehmend). Der
/// Hinweis führt deshalb ins Konto zum Knopf, statt die Anfrage selbst
/// auszulösen — sonst verbraucht er den einen Versuch, den es gibt.
///
/// Die Reihenfolge ist keine Willkür: Ohne `Notification` ist die Erlaubnis
/// gar nicht erreichbar, also kommt die Installation zuerst.
WebHinweis webHinweisFuer(Browserfenster fenster) {
  if (!fenster.imBrowser) return WebHinweis.keiner;

  if (!fenster.benachrichtigungenMoeglich) {
    // Schon installiert und trotzdem keine Meldungen: Dann liegt es nicht
    // an der Installation, und ein Hinweis wäre ein falsches Versprechen.
    if (fenster.alsAppInstalliert) return WebHinweis.keiner;
    return _sofernNichtWeggewischt(fenster, WebHinweis.installieren);
  }

  // `granted` und `denied` sind beide erledigt — im zweiten Fall kann die
  // App nicht erneut fragen, der Weg steht im Konto.
  if (fenster.erlaubnis != 'default') return WebHinweis.keiner;
  return _sofernNichtWeggewischt(fenster, WebHinweis.erlauben);
}

WebHinweis _sofernNichtWeggewischt(Browserfenster fenster, WebHinweis was) =>
    fenster.hinweisWeggewischt(webHinweisSchluessel(was))
        ? WebHinweis.keiner
        : was;

/// Zählt hoch, wenn sich am Hinweis etwas geändert hat.
///
/// Der Stand steckt im Browser und nicht in einem Provider — nach einem
/// Wegwischen muss die Startseite also von Hand zum Neubauen gebracht
/// werden.
final webHinweisTickProvider = StateProvider<int>((ref) => 0);

/// Der Hinweis für die Startseite, neu berechnet nach jedem Tick.
final webHinweisProvider = Provider<WebHinweis>((ref) {
  ref.watch(webHinweisTickProvider);
  return webHinweisFuer(ref.watch(browserfensterProvider));
});
