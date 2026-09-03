part of '../providers.dart';

// ============================================================================
// Freundschaftsanfragen: ablehnen mit Rückgängig-Frist
// ============================================================================

/// Wie lange „Rückgängig" nach einem Ablehnen offensteht.
///
/// Fünf Sekunden sind lang genug, um einen Fehltipp zu bemerken, und kurz
/// genug, dass niemand darauf wartet. Derselbe Wert wie bei der
/// Snackbar — beide Fristen müssen zusammenpassen, sonst verspricht die
/// Schaltfläche etwas, das der Hintergrund schon getan hat.
const rueckgaengigFrist = Duration(seconds: 5);

/// Anfragen, die abgelehnt **wurden**, deren Löschung aber noch aussteht.
///
/// **Warum aufgeschoben und nicht rückgängig gemacht:** Ablehnen löscht
/// die Zeile in `friendships`. Wiederherstellen könnte nur der andere —
/// `friendships_insert` verlangt `requester_id = auth.uid()`, und das ist
/// er, nicht ich. Ein „Rückgängig", das den Server um etwas bittet, was
/// er ablehnen muss, wäre ein Versprechen ohne Deckung.
///
/// Also andersherum: Die Anfrage verschwindet sofort aus allen Listen,
/// gelöscht wird sie erst nach [rueckgaengigFrist]. In diesem Fenster
/// kostet „Rückgängig" keinen Serveraufruf — es unterbleibt einer.
///
/// **Was passiert, wenn die App in diesen Sekunden stirbt:** nichts. Die
/// Anfrage bleibt offen und taucht beim nächsten Start wieder auf. Das
/// ist die harmlose Richtung: Eine Anfrage zu viel ist ärgerlich, eine
/// fälschlich gelöschte ist weg.
class AbgelehnteAnfragen extends Notifier<Set<String>> {
  /// IDs, für die „Rückgängig" gedrückt wurde, während die Frist lief.
  final _zurueckgenommen = <String>{};

  @override
  Set<String> build() => const {};

  /// Blendet die Anfrage sofort aus und löscht sie nach [frist].
  ///
  /// Rückgabe: `null`, wenn zurückgenommen wurde; sonst, ob der Server
  /// das Löschen übernommen hat. Ein `false` ist kein Schönheitsfehler —
  /// wer glaubt, abgelehnt zu haben, rechnet nicht mehr damit, gesehen zu
  /// werden. Die Anfrage kommt dann sichtbar zurück.
  Future<bool?> ablehnen(
    String friendshipId, {
    Duration frist = rueckgaengigFrist,
  }) async {
    _zurueckgenommen.remove(friendshipId);
    state = {...state, friendshipId};

    await Future<void>.delayed(frist);
    if (_zurueckgenommen.remove(friendshipId)) return null;

    final online = await ref.read(onlineServiceProvider.future);
    final ok =
        await online?.friends.respondRequest(friendshipId, accept: false) ??
            false;
    // Ob erfolgreich oder nicht: Die Sperre gehört wieder weg. Bei Erfolg
    // ist die Zeile fort und die Liste zeigt sie ohnehin nicht mehr, bei
    // Misserfolg muss sie zurückkommen.
    state = {...state}..remove(friendshipId);
    if (ok) {
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(onlineFriendsProvider);
    }
    return ok;
  }

  /// „Rückgängig" — die Löschung findet nicht statt.
  ///
  /// Wirkt nur innerhalb der Frist; danach ist die Zeile fort und der
  /// Aufruf verpufft folgenlos.
  void zuruecknehmen(String friendshipId) {
    _zurueckgenommen.add(friendshipId);
    state = {...state}..remove(friendshipId);
  }
}

final abgelehnteAnfragenProvider =
    NotifierProvider<AbgelehnteAnfragen, Set<String>>(AbgelehnteAnfragen.new);

/// Die Anfragen, die wirklich noch offen sind.
///
/// Fünf Stellen zeigten bisher `friendRequestsProvider` direkt — zwei
/// Listen, zwei Zähler am Glockensymbol und die Kennzahl im Profil. Jede
/// hätte die aufgeschobene Ablehnung einzeln herausfiltern müssen, und
/// eine hätte es vergessen: Der Zähler zeigt 1, die Liste darunter ist
/// leer. Der Filter gehört deshalb genau einmal hierher.
final offeneAnfragenProvider = Provider<List<FriendRequest>>((ref) {
  final alle = ref.watch(friendRequestsProvider).valueOrNull ?? const [];
  final abgelehnt = ref.watch(abgelehnteAnfragenProvider);
  if (abgelehnt.isEmpty) return alle;
  return [
    for (final a in alle)
      if (!abgelehnt.contains(a.friendshipId)) a,
  ];
});
