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
