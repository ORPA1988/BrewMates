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
