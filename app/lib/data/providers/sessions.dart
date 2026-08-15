part of '../providers.dart';

// Beacons
//
// Teil von `providers.dart` (Backlog B-4). Als `part`, nicht als
// eigene Bibliothek: Die Provider greifen auf gemeinsame private
// Helfer zu (`_now`, `_syncTickProvider`). Ein `part` teilt den
// Namensraum, ein Import nicht — sonst muessten interne Details
// oeffentlich werden, nur damit die Datei kleiner wird.

// ============================================================================
// Sessions
// ============================================================================

/// Aktive Sessions: abgemeldet = lokal (inkl. Demo); angemeldet = eigene
/// aktive Session + Live-Sessions echter Freunde.
final activeSessionsProvider = StreamProvider<List<SessionDetails>>((ref) {
  final localStream =
      ref.watch(databaseProvider).watchActiveSessions(_now(ref));
  if (!ref.watch(isSignedInProvider)) return localStream;
  final remote = ref.watch(remoteSessionsProvider).valueOrNull ?? const [];
  return localStream.map((locals) => [
        ...locals.where((s) => s.host.isMe),
        ...remote.map(remoteSessionToDetails),
      ]);
});

final myActiveSessionProvider = StreamProvider<Session?>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(null);
  return ref.watch(databaseProvider).watchMyActiveSession(me.id, _now(ref));
});

final sessionProvider =
    StreamProvider.family<SessionDetails?, String>((ref, id) {
  if (isRemoteId(id)) {
    final remote = ref.watch(remoteSessionsProvider).valueOrNull ?? const [];
    RemoteSession? match;
    for (final s in remote) {
      if ('$remotePrefix${s.id}' == id) match = s;
    }
    return Stream.value(match == null ? null : remoteSessionToDetails(match));
  }
  return ref.watch(databaseProvider).watchSession(id);
});

final sessionCheckinsProvider =
    StreamProvider.family<List<CheckinDetails>, String>((ref, id) {
  if (isRemoteId(id)) return Stream.value(const []);
  return ref.watch(databaseProvider).watchSessionCheckins(id);
});
