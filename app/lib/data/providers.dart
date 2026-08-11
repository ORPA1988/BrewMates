import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/badges.dart';
import 'community_sync.dart';
import 'db/database.dart';

// ============================================================================
// Infrastruktur
// ============================================================================

/// In Tests per overrideWithValue durch AppDatabase.memory() ersetzbar.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// Tickt jede halbe Minute – hält „aktive Session"-Abfragen frisch und
/// beendet abgelaufene Sessions (Pendant zum pg_cron-Job im Backend).
/// Bewusst mit eigenem Timer statt Stream.periodic, damit der Timer beim
/// Dispose synchron gecancelt wird (wichtig für Widget-Tests).
final clockProvider = StreamProvider<DateTime>((ref) {
  final db = ref.watch(databaseProvider);
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    unawaited(db.endExpiredSessions(DateTime.now()));
    controller.add(DateTime.now());
  });
  ref.onDispose(() {
    timer.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

DateTime _now(Ref ref) =>
    ref.watch(clockProvider).valueOrNull ?? DateTime.now();

// ============================================================================
// Community-Datenbank (GitHub)
// ============================================================================

final communitySyncProvider =
    Provider<CommunitySync>((ref) => CommunitySync(ref.watch(databaseProvider)));

/// Läuft einmal beim App-Start: gebündelte Daten importieren, dann still
/// die neueste Fassung von GitHub holen (offline kein Fehler).
final communityBootstrapProvider = FutureProvider<void>((ref) async {
  final sync = ref.watch(communitySyncProvider);
  await sync.importBundledData();
  await sync.syncSilently();
});

// ============================================================================
// Profil & Freunde
// ============================================================================

final meProvider = StreamProvider<Profile>(
    (ref) => ref.watch(databaseProvider).watchMe());

final friendsProvider = StreamProvider<List<Profile>>(
    (ref) => ref.watch(databaseProvider).watchFriends());

// ============================================================================
// Feed, Toasts, Kommentare
// ============================================================================

final feedProvider = StreamProvider<List<CheckinDetails>>(
    (ref) => ref.watch(databaseProvider).watchFeed());

final myDiaryProvider = StreamProvider<List<CheckinDetails>>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchFeed(onlyProfileId: me.id);
});

final toastCountProvider = StreamProvider.family<int, String>(
    (ref, checkinId) => ref.watch(databaseProvider).watchToastCount(checkinId));

final toastedByMeProvider =
    StreamProvider.family<bool, String>((ref, checkinId) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(false);
  return ref.watch(databaseProvider).watchToastedByMe(checkinId, me.id);
});

final commentCountProvider = StreamProvider.family<int, String>((ref,
        checkinId) =>
    ref.watch(databaseProvider).watchCommentCount(checkinId));

final commentsProvider =
    StreamProvider.family<List<(Comment, Profile)>, String>((ref, checkinId) =>
        ref.watch(databaseProvider).watchComments(checkinId));

// ============================================================================
// Sessions
// ============================================================================

final activeSessionsProvider = StreamProvider<List<SessionDetails>>((ref) =>
    ref.watch(databaseProvider).watchActiveSessions(_now(ref)));

final myActiveSessionProvider = StreamProvider<Session?>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(null);
  return ref.watch(databaseProvider).watchMyActiveSession(me.id, _now(ref));
});

final sessionProvider = StreamProvider.family<SessionDetails?, String>(
    (ref, id) => ref.watch(databaseProvider).watchSession(id));

final sessionCheckinsProvider =
    StreamProvider.family<List<CheckinDetails>, String>((ref, id) =>
        ref.watch(databaseProvider).watchSessionCheckins(id));

// ============================================================================
// Biere & Wunschliste
// ============================================================================

typedef BeerFilter = ({String search, String? style});

final beersProvider =
    StreamProvider.family<List<BeerWithBrewery>, BeerFilter>((ref, filter) =>
        ref
            .watch(databaseProvider)
            .watchBeers(search: filter.search, style: filter.style));

final beerStylesProvider =
    FutureProvider<List<String>>((ref) => ref.watch(databaseProvider).allStyles());

final beerProvider = StreamProvider.family<BeerWithBrewery?, String>(
    (ref, id) => ref.watch(databaseProvider).watchBeer(id));

final beerStatsProvider = StreamProvider.family<BeerStats, String>(
    (ref, id) => ref.watch(databaseProvider).watchBeerStats(id));

final breweryProvider = StreamProvider.family<Brewery?, String>(
    (ref, id) => ref.watch(databaseProvider).watchBrewery(id));

final breweryBeersProvider =
    StreamProvider.family<List<BeerWithBrewery>, String>((ref, id) =>
        ref.watch(databaseProvider).watchBeersOfBrewery(id));

final breweriesWithLocationProvider = StreamProvider<List<Brewery>>(
    (ref) => ref.watch(databaseProvider).watchBreweriesWithLocation());

final wishlistProvider = StreamProvider<List<BeerWithBrewery>>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchWishlist(me.id);
});

final onWishlistProvider = StreamProvider.family<bool, String>((ref, beerId) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(false);
  return ref.watch(databaseProvider).watchOnWishlist(me.id, beerId);
});

// ============================================================================
// Abzeichen & Statistiken
// ============================================================================

final myBadgesProvider = StreamProvider<List<UserBadge>>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchMyBadges(me.id);
});

/// Fortschritt aller Abzeichen; rechnet neu, wenn sich Tagebuch oder
/// verdiente Abzeichen ändern.
final badgeProgressProvider = FutureProvider<List<BadgeProgress>>((ref) async {
  final me = await ref.watch(meProvider.future);
  ref.watch(myDiaryProvider);
  ref.watch(myBadgesProvider);
  return BadgeEngine(ref.watch(databaseProvider)).progressList(me.id);
});

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final me = await ref.watch(meProvider.future);
  ref.watch(myDiaryProvider);
  ref.watch(myBadgesProvider);
  return ref.watch(databaseProvider).computeProfileStats(me.id);
});

// ============================================================================
// Aktionen (Schreiboperationen + Badge-Auswertung)
// ============================================================================

final actionsProvider = Provider<BrewActions>((ref) => BrewActions(ref));

class BrewActions {
  BrewActions(this._ref);

  final Ref _ref;
  final _uuid = const Uuid();

  AppDatabase get _db => _ref.read(databaseProvider);

  Future<Profile> _me() => _db.getMe();

  /// Check-in speichern. Läuft die aktive eigene Session, wird der Check-in
  /// ihr automatisch zugeordnet. Gibt neu verdiente Abzeichen zurück.
  Future<List<BadgeDef>> createCheckin({
    required String beerId,
    double? rating,
    String? note,
    String? venueName,
    List<String> flavorTags = const [],
    ServingStyle? servingStyle,
  }) async {
    final me = await _me();
    final now = DateTime.now();
    final session = await _db.getMyActiveSession(me.id, now);
    await _db.into(_db.checkins).insert(CheckinsCompanion.insert(
          id: _uuid.v4(),
          profileId: me.id,
          beerId: beerId,
          sessionId: Value(session?.id),
          venueName: Value(venueName ?? session?.venueName),
          rating: Value(rating),
          note: Value((note ?? '').trim().isEmpty ? null : note!.trim()),
          flavorTags: Value(flavorTags.join(',')),
          servingStyle: Value(servingStyle),
          createdAt: now,
        ));
    return BadgeEngine(_db).evaluate(me.id);
  }

  /// Session starten („der eine Tap"). Gibt neu verdiente Abzeichen zurück.
  Future<List<BadgeDef>> startSession({
    required String venueName,
    String? message,
    required SessionVisibility visibility,
    required Duration autoEnd,
    double? latitude,
    double? longitude,
  }) async {
    final me = await _me();
    final now = DateTime.now();
    // Nur eine aktive Session gleichzeitig.
    final current = await _db.getMyActiveSession(me.id, now);
    if (current != null) {
      await _db.endSession(current.id, now);
    }
    await _db.into(_db.sessions).insert(SessionsCompanion.insert(
          id: _uuid.v4(),
          hostId: me.id,
          venueName: Value(venueName),
          message: Value((message ?? '').trim().isEmpty ? null : message),
          visibility: visibility,
          status: SessionStatus.active,
          startedAt: now,
          expiresAt: now.add(autoEnd),
          latitude: Value(latitude),
          longitude: Value(longitude),
        ));
    return BadgeEngine(_db).evaluate(me.id);
  }

  Future<void> endMySession() async {
    final me = await _me();
    final now = DateTime.now();
    final current = await _db.getMyActiveSession(me.id, now);
    if (current != null) await _db.endSession(current.id, now);
  }

  /// „Bin dabei!" auf die Session eines Freundes.
  Future<List<BadgeDef>> joinSession(String sessionId) async {
    final me = await _me();
    await _db.joinSession(sessionId, me.id, ParticipantKind.joined);
    return BadgeEngine(_db).evaluate(me.id);
  }

  /// Fern-Prost auf eine Session.
  Future<void> toastSession(String sessionId) async {
    final me = await _me();
    await _db.joinSession(sessionId, me.id, ParticipantKind.toast);
  }

  Future<List<BadgeDef>> toggleToast(String checkinId) async {
    final me = await _me();
    await _db.toggleToast(checkinId, me.id);
    return BadgeEngine(_db).evaluate(me.id);
  }

  Future<void> addComment(String checkinId, String body) async {
    final me = await _me();
    await _db.into(_db.comments).insert(CommentsCompanion.insert(
          id: _uuid.v4(),
          checkinId: checkinId,
          profileId: me.id,
          body: body.trim(),
          createdAt: DateTime.now(),
        ));
  }

  Future<void> toggleWishlist(String beerId) async {
    final me = await _me();
    await _db.toggleWishlist(me.id, beerId, DateTime.now());
  }

  /// Community-Einreichung: neues Bier (+ ggf. neue Brauerei) anlegen.
  Future<String> addBeer({
    required String name,
    required String style,
    required String breweryName,
    required String breweryCountry,
    required String breweryCity,
    double? abv,
    bool isAlcoholFree = false,
    String? description,
  }) async {
    final brewery = await _db.getOrCreateBrewery(
      id: _uuid.v4(),
      name: breweryName.trim(),
      country: breweryCountry.trim(),
      city: breweryCity.trim(),
    );
    final beerId = _uuid.v4();
    await _db.addBeer(
      id: beerId,
      breweryId: brewery.id,
      name: name.trim(),
      style: style.trim(),
      abv: abv,
      isAlcoholFree: isAlcoholFree,
      description: description,
    );
    return beerId;
  }

  Future<void> updateProfile(
          {String? displayName, String? avatarEmoji, String? bio}) =>
      _db.updateMe(
          displayName: displayName, avatarEmoji: avatarEmoji, bio: bio);
}

/// Alle wählbaren Geschmacks-Tags (Check-in-Formular).
const List<String> kFlavorTags = [
  'süffig',
  'hopfig',
  'malzig',
  'fruchtig',
  'sauer',
  'würzig',
  'schokoladig',
  'rauchig',
  'blumig',
  'karamellig',
];
