part of '../providers.dart';

// Konten, Freunde, Live-Beacon, Rechte
//
// Teil von `providers.dart` (Backlog B-4). Als `part`, nicht als
// eigene Bibliothek: Die Provider greifen auf gemeinsame private
// Helfer zu (`_now`, `_syncTickProvider`). Ein `part` teilt den
// Namensraum, ein Import nicht — sonst muessten interne Details
// oeffentlich werden, nur damit die Datei kleiner wird.

// ============================================================================
// Online-Stufe (Beta): Konten, Freunde, Live-Beacon
// ============================================================================

/// null, solange keine Supabase-Konfiguration vorliegt – die App läuft
/// dann vollständig lokal (wie bisher).
final onlineServiceProvider =
    FutureProvider<OnlineService?>((ref) => OnlineService.initialize());

/// Der angemeldete Supabase-Nutzer (null = abgemeldet/offline).
final onlineUserProvider = StreamProvider<User?>((ref) async* {
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) {
    yield null;
    return;
  }
  yield online.currentUser;
  await for (final state in online.authChanges) {
    yield state.session?.user;
  }
});

final isSignedInProvider =
    Provider<bool>((ref) => ref.watch(onlineUserProvider).valueOrNull != null);

final myRemoteProfileProvider = FutureProvider<RemoteProfile?>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  return online?.myProfile();
});

/// Aktive Sessions echter Freunde (Realtime).
final remoteSessionsProvider =
    StreamProvider<List<RemoteSession>>((ref) async* {
  final online = await ref.watch(onlineServiceProvider.future);
  final user = ref.watch(onlineUserProvider).valueOrNull;
  if (online == null || user == null) {
    yield const [];
    return;
  }
  yield* online.sessions.friendSessionsStream();
});

/// Check-ins echter Freunde (Abruf beim Start + alle 30 s über die Clock).
final remoteFeedProvider = FutureProvider<List<RemoteCheckin>>((ref) async {
  ref.watch(onlineUserProvider);
  ref.watch(clockProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return const [];
  // Gleiches Fenster wie der lokale Teil – „mehr laden" holt auch
  // serverseitig nach, statt bei den ersten 50 stehenzubleiben.
  return online.checkins.friendCheckins(limit: ref.watch(feedLimitProvider));
});

final onlineFriendsProvider =
    FutureProvider<List<RemoteProfile>>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.friends.friends();
});

/// Eigene Blockliste (Migration 0009); leer, solange niemand blockiert ist.
final blockedProfilesProvider =
    FutureProvider<List<RemoteProfile>>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.friends.blockedProfiles();
});

/// Sichtbarer Kartenausschnitt (von der Karte gesetzt, entprellt).
typedef MapBounds = ({
  double minLat,
  double minLng,
  double maxLat,
  double maxLng,
});

final mapBoundsProvider = StateProvider<MapBounds?>((ref) => null);

/// Anzahl aktiver Nicht-Freunde im Kartenausschnitt („x weitere BrewMates
/// aktiv"). Aktualisiert bei Kartenbewegung und über die 30-s-Clock.
final otherActiveCountProvider = FutureProvider<int>((ref) async {
  final bounds = ref.watch(mapBoundsProvider);
  ref.watch(clockProvider);
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (bounds == null || online == null || online.currentUser == null) {
    return 0;
  }
  return online.sessions.countOtherActiveSessions(
    minLat: bounds.minLat,
    minLng: bounds.minLng,
    maxLat: bounds.maxLat,
    maxLng: bounds.maxLng,
  );
});

/// Bin ich Admin? (Rollen vergibt nur ein Admin; der erste Admin wird
/// serverseitig per E-Mail-Bootstrap gesetzt.)
final isAdminProvider = FutureProvider<bool>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return false;
  return online.amIAdmin();
});

/// Meine freigeschalteten Funktionen (premium, moderation, …).
final myFeaturesProvider = FutureProvider<Map<String, bool>>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  final user = online?.currentUser;
  if (online == null || user == null) return const {};
  return online.featuresOf(user.id);
});

final friendRequestsProvider =
    FutureProvider<List<FriendRequest>>((ref) async {
  ref.watch(onlineUserProvider);
  ref.watch(clockProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.friends.incomingRequests();
});

/// Anfragen, die ich selbst gestellt habe und die noch offen sind.
///
/// Sie waren bisher unsichtbar: Wer jemanden angefragt hatte, sah davon
/// nichts — nicht in der Suche, nicht in der Freundesliste. Der zweite
/// Versuch lief dann in „Anfrage laeuft schon", ohne dass je erkennbar
/// war, dass man selbst der Absender ist.
final outgoingRequestsProvider =
    FutureProvider<List<OutgoingRequest>>((ref) async {
  ref.watch(onlineUserProvider);
  ref.watch(clockProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.friends.outgoingRequests();
});
