import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../core/app_update.dart';
import '../core/config.dart';
import '../domain/account_level.dart';
import '../domain/badges.dart';
import '../domain/challenges.dart';
import '../features/scan/barcode_lookup.dart';
import '../widgets/badge_celebration.dart';
import 'community_sync.dart';
import 'db/database.dart';
import 'location_service.dart';
import 'venue_sync.dart';
import 'online/online_service.dart';
import 'online/remote_mapping.dart';

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

/// Läuft einmal beim App-Start. Das Future ist fertig, sobald die
/// GEBÜNDELTEN Daten importiert sind (darauf darf z. B. der Scanner
/// warten); der GitHub-Abgleich läuft danach im Hintergrund weiter.
final communityBootstrapProvider = FutureProvider<void>((ref) async {
  final sync = ref.watch(communitySyncProvider);
  await sync.importBundledData();
  unawaited(sync.syncSilently());
});

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
  yield* online.friendSessionsStream();
});

/// Check-ins echter Freunde (Abruf beim Start + alle 30 s über die Clock).
final remoteFeedProvider = FutureProvider<List<RemoteCheckin>>((ref) async {
  ref.watch(onlineUserProvider);
  ref.watch(clockProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return const [];
  return online.friendCheckins();
});

final onlineFriendsProvider =
    FutureProvider<List<RemoteProfile>>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.friends();
});

/// Eigene Blockliste (Migration 0009); leer, solange niemand blockiert ist.
final blockedProfilesProvider =
    FutureProvider<List<RemoteProfile>>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.blockedProfiles();
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
  return online.countOtherActiveSessions(
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
  return online.incomingRequests();
});

// ============================================================================
// Hero-Funktionen: Barcode-Lookup & Standort
// ============================================================================

final barcodeLookupProvider = Provider<BarcodeLookup>((ref) => BarcodeLookup(
      ref.watch(databaseProvider),
      // Zwischenschritt der Scan-Kette: von anderen Nutzern direkt
      // eingetragene Community-Biere (nur angemeldet erreichbar).
      communityLookup: (ean) async {
        final online = await ref.read(onlineServiceProvider.future);
        return online?.communityBeerByBarcode(ean);
      },
    ));

/// Echte Community-Bewertung (Ø + Anzahl) aus den Online-Check-ins aller
/// Nutzer – ersetzt schrittweise die redaktionelle community_rating.
final onlineRatingStatsProvider =
    FutureProvider.family<(double, int)?, String>((ref, beerId) async {
  if (!ref.watch(isSignedInProvider)) return null;
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;
  final item = await ref.watch(beerProvider(beerId).future);
  if (item == null) return null;
  return online.beerRatingStats(item.beer.name, item.brewery.name);
});

/// In Widget-Tests per overrideWithValue durch einen Fake ersetzen.
final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

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

/// Feed: abgemeldet = lokale Daten inkl. Demo-Freunde; angemeldet = eigene
/// lokale Check-ins + die echter Freunde (Demo-Inhalte verschwinden).
final feedProvider = StreamProvider<List<CheckinDetails>>((ref) {
  final db = ref.watch(databaseProvider);
  if (!ref.watch(isSignedInProvider)) return db.watchFeed();
  final remote = ref.watch(remoteFeedProvider).valueOrNull ?? const [];
  return db.watchFeed().map((locals) {
    final merged = [
      ...locals.where((c) => c.author.isMe),
      ...remote.map(remoteCheckinToDetails),
    ]..sort((a, b) => b.checkin.createdAt.compareTo(a.checkin.createdAt));
    return merged;
  });
});

final myDiaryProvider = StreamProvider<List<CheckinDetails>>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchFeed(onlyProfileId: me.id);
});

/// Lokale Check-ins, die noch nicht im Online-Konto liegen – z. B. weil sie
/// offline entstanden sind (null = Status gerade nicht feststellbar).
final pendingCheckinUploadProvider =
    FutureProvider<List<CheckinDetails>?>((ref) async {
  if (!ref.watch(isSignedInProvider)) return null;
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;
  final diary = await ref.watch(myDiaryProvider.future);
  final candidates = [
    for (final d in diary)
      if (OnlineService.isUploadable(d)) d,
  ];
  if (candidates.isEmpty) return const [];
  final remoteIds = await online.myRemoteCheckinIds();
  if (remoteIds == null) return null;
  return [
    for (final d in candidates)
      if (!remoteIds.contains(d.checkin.id)) d,
  ];
});

/// 30-Sekunden-Uhr auf einen 5-Minuten-Sync-Takt heruntergeteilt: Der Wert
/// ändert sich nur alle 5 Minuten, Abhängige laufen also nicht bei jedem
/// Uhr-Tick neu.
final _syncTickProvider = Provider<int>((ref) {
  final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  return now.millisecondsSinceEpoch ~/ (5 * 60 * 1000);
});

// ============================================================================
// Gasthäuser (gemeinsame Datenbank; Cache in Drift, Wahrheit in Supabase)
// ============================================================================

final venueSyncServiceProvider =
    Provider<VenueSync>((ref) => VenueSync(ref.watch(databaseProvider)));

/// Automatischer Cache-Abgleich der Gasthaus-DB: bei Anmeldung und im
/// 5-Minuten-Takt (gleicher Takt wie der Check-in-Sync); die AppShell hält
/// den Provider am Leben. Rückgabe: zuletzt übernommene Zeilen.
final venueSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(_syncTickProvider);
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return 0;
  final imported = await ref.read(venueSyncServiceProvider).sync(online);
  return imported;
});

final venuesWithLocationProvider = StreamProvider<List<Venue>>(
    (ref) => ref.watch(databaseProvider).watchVenuesWithLocation());

/// Alle Gasthäuser aus dem Cache (Gasthausliste; Sortierung macht die UI).
final allVenuesProvider = StreamProvider<List<Venue>>(
    (ref) => ref.watch(databaseProvider).watchAllVenues());

final venueSearchProvider = StreamProvider.family<List<Venue>, String>(
    (ref, query) => ref.watch(databaseProvider).watchVenueSearch(query));

final venueProvider = StreamProvider.family<Venue?, String>(
    (ref, id) => ref.watch(databaseProvider).watchVenue(id));

// ============================================================================
// Automatischer Update-Check (GitHub-Releases; nur Android relevant)
// ============================================================================

/// Prüft einmal pro App-Start, ob ein neueres Release existiert.
/// null = aktuell/offline/kein Android. In Tests via override abschaltbar.
final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  if (kIsWeb || !Platform.isAndroid) return null;
  final client = http.Client();
  try {
    return await checkForUpdate(client,
        currentVersion: AppConfig.appVersion);
  } finally {
    client.close();
  }
});

/// Update-Hinweis auf Home wurde weggewischt (bis zum nächsten App-Start).
final updateDismissedProvider = StateProvider<bool>((ref) => false);

// ============================================================================
// Vertrauensstufen (Account-Levelsystem, Migration 0013)
// ============================================================================

/// Merkt sich die zuletzt gesehene Stufe, um Aufstiege zu erkennen.
final _lastSeenLevelProvider = StateProvider<int?>((ref) => null);

/// Eigene Vertrauensstufe + Punkte (null = offline/abgemeldet). Bei einem
/// Aufstieg wird ein [CelebrationItem] in [levelUpProvider] hinterlegt.
final accountLevelProvider =
    FutureProvider<({int level, int points})?>((ref) async {
  ref.watch(onlineUserProvider);
  ref.watch(myDiaryProvider); // Punkte ändern sich mit Check-ins
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return null;
  final info = await online.myAccountLevelInfo();
  if (info != null) {
    final last = ref.read(_lastSeenLevelProvider);
    if (last != null && info.level > last && info.level >= 2) {
      ref.read(levelUpProvider.notifier).state = CelebrationItem(
        emoji: levelEmoji(info.level),
        name: levelName(info.level),
        description:
            'Neue Vertrauensstufe erreicht – danke für deine Datenpflege!',
        headline: 'Stufenaufstieg! 🎖',
      );
    }
    ref.read(_lastSeenLevelProvider.notifier).state = info.level;
  }
  return info;
});

/// Wartende Level-Up-Feier; die UI konsumiert und leert den Wert.
final levelUpProvider = StateProvider<CelebrationItem?>((ref) => null);

// ============================================================================
// Challenges (Herausforderungen mit Belohnungs-Badge, Admin-gepflegt)
// ============================================================================

/// Holt Challenges online, aktualisiert den Offline-Cache und liefert die
/// Cache-Zeilen (offline: nur Cache). Aktualisiert bei Anmeldung und im
/// 5-Minuten-Takt.
final challengesProvider =
    FutureProvider<List<ChallengeCacheData>>((ref) async {
  ref.watch(_syncTickProvider);
  ref.watch(onlineUserProvider);
  final db = ref.watch(databaseProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online != null && online.currentUser != null) {
    final rows = await online.listChallenges();
    if (rows != null) {
      await db.upsertChallengeCache([
        for (final r in rows)
          ChallengeCacheCompanion(
            id: Value(r['id'] as String),
            title: Value(r['title'] as String),
            description: Value((r['description'] as String?) ?? ''),
            emoji: Value((r['emoji'] as String?) ?? '🏆'),
            ruleJson: Value(json.encode(r['rule'])),
            startsAt:
                Value(DateTime.parse(r['starts_at'] as String).toLocal()),
            endsAt: Value(DateTime.parse(r['ends_at'] as String).toLocal()),
          ),
      ]);
    }
  }
  return db.allCachedChallenges();
});

/// Fortschritt aller aktiven Challenges (abgeschlossene behalten Häkchen).
final challengeProgressProvider =
    FutureProvider<List<ChallengeProgress>>((ref) async {
  final me = await ref.watch(meProvider.future);
  ref.watch(myDiaryProvider);
  ref.watch(myBadgesProvider);
  await ref.watch(challengesProvider.future);
  return ChallengeEngine(ref.watch(databaseProvider)).progressList(me.id);
});

/// Verdiente Challenge-Trophäen für die Abzeichen-Galerie; Titel/Emoji
/// kommen aus dem Challenge-Cache (funktioniert auch nach Challenge-Ende).
final earnedChallengeBadgesProvider = FutureProvider<
    List<({String emoji, String title, DateTime awardedAt})>>((ref) async {
  final me = await ref.watch(meProvider.future);
  ref.watch(myBadgesProvider);
  final db = ref.watch(databaseProvider);
  final rows = await db.earnedChallengeBadges(me.id);
  if (rows.isEmpty) return const [];
  final cache = await db.allCachedChallenges();
  return [
    for (final row in rows)
      () {
        final idPrefix = row.badgeSlug.substring('challenge-'.length);
        for (final c in cache) {
          if (c.id.startsWith(idPrefix)) {
            return (
              emoji: c.emoji,
              title: c.title,
              awardedAt: row.awardedAt,
            );
          }
        }
        return (
          emoji: '🏆',
          title: 'Challenge',
          awardedAt: row.awardedAt,
        );
      }(),
  ];
});

/// Automatischer Konto-Abgleich: überträgt offline entstandene Check-ins,
/// sobald Konto und Verbindung da sind – bei Anmeldung, nach jedem lokalen
/// Check-in (Tagebuch-Stream) und alle 5 Minuten als Nachzügler-Retry.
/// Dank Upsert über die Client-UUIDs idempotent; die AppShell hält den
/// Provider am Leben. Rückgabe: zuletzt übertragene Anzahl.
final checkinAutoSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return 0;
  final pending =
      await ref.watch(pendingCheckinUploadProvider.future) ?? const [];
  if (pending.isEmpty) return 0;
  final uploaded = await online.uploadLocalCheckins(pending) ?? 0;
  if (uploaded > 0) ref.invalidate(pendingCheckinUploadProvider);
  return uploaded;
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

/// Brauerei-Suche für den Entdecken-Tab (leer bei leerem Suchbegriff).
final brewerySearchProvider = StreamProvider.family<List<Brewery>, String>(
    (ref, search) => search.trim().isEmpty
        ? Stream.value(const <Brewery>[])
        : ref.watch(databaseProvider).watchBreweriesSearch(search.trim()));

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
  final online = await ref.watch(onlineServiceProvider.future);
  return BadgeEngine(ref.watch(databaseProvider)).progressList(me.id,
      onlineUserId: online?.currentUser?.id);
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

  /// Online-Service, falls konfiguriert UND angemeldet – sonst null.
  Future<OnlineService?> _online() async {
    final online = await _ref.read(onlineServiceProvider.future);
    return (online != null && online.currentUser != null) ? online : null;
  }

  /// Abzeichen auswerten (inkl. Datenpflege-Badges, die die Supabase-UUID
  /// brauchen). Auch von Screens nutzbar, z. B. nach dem Anlegen eines
  /// Gasthauses.
  Future<List<BadgeDef>> evaluateBadges() async {
    final me = await _me();
    final online = await _online();
    return BadgeEngine(_db)
        .evaluate(me.id, onlineUserId: online?.currentUser?.id);
  }

  /// Check-in speichern. Läuft die aktive eigene Session, wird der Check-in
  /// ihr automatisch zugeordnet. Gibt neu verdiente Abzeichen zurück.
  /// Check-in speichern. Gibt Feier-Einträge zurück: neu verdiente
  /// Abzeichen UND neu abgeschlossene Challenges.
  Future<List<CelebrationItem>> createCheckin({
    required String beerId,
    double? rating,
    String? note,
    String? venueName,
    String? venueId,
    List<String> flavorTags = const [],
    ServingStyle? servingStyle,
  }) async {
    final me = await _me();
    final now = DateTime.now();
    final session = await _db.getMyActiveSession(me.id, now);
    final checkinId = _uuid.v4();
    await _db.into(_db.checkins).insert(CheckinsCompanion.insert(
          id: checkinId,
          profileId: me.id,
          beerId: beerId,
          sessionId: Value(session?.id),
          venueId: Value(venueId ?? session?.venueId),
          venueName: Value(venueName ?? session?.venueName),
          rating: Value(rating),
          note: Value((note ?? '').trim().isEmpty ? null : note!.trim()),
          flavorTags: Value(flavorTags.join(',')),
          servingStyle: Value(servingStyle),
          createdAt: now,
        ));
    // Online spiegeln (Freunde sehen den Check-in in ihrem Feed).
    final online = await _online();
    if (online != null) {
      final mine = await _db.myCheckinsDetailed(me.id);
      for (final details in mine) {
        if (details.checkin.id == checkinId) {
          unawaited(online.insertCheckin(details));
          break;
        }
      }
    }
    final badges = await BadgeEngine(_db)
        .evaluate(me.id, onlineUserId: online?.currentUser?.id);
    // Challenges prüfen: Abschluss lokal als Badge festhalten und
    // best-effort online melden (idempotent; offline holt der nächste
    // Durchlauf es nach).
    final completed = await ChallengeEngine(_db).evaluate(me.id);
    if (online != null) {
      for (final def in completed) {
        unawaited(online.completeChallenge(def.id));
      }
    }
    return [
      for (final b in badges) CelebrationItem.fromBadge(b),
      for (final def in completed) CelebrationItem.fromChallenge(def),
    ];
  }

  /// Session starten („der eine Tap"). Gibt neu verdiente Abzeichen zurück.
  /// [venueName] darf fehlen (Beacon „unterwegs" mit reiner GPS-Position).
  Future<List<BadgeDef>> startSession({
    String? venueName,
    String? venueId,
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
      await endMySession();
    }
    final sessionId = _uuid.v4();
    await _db.into(_db.sessions).insert(SessionsCompanion.insert(
          id: sessionId,
          hostId: me.id,
          venueId: Value(venueId),
          venueName: Value(venueName),
          message: Value((message ?? '').trim().isEmpty ? null : message),
          visibility: visibility,
          status: SessionStatus.active,
          startedAt: now,
          expiresAt: now.add(autoEnd),
          latitude: Value(latitude),
          longitude: Value(longitude),
        ));
    // Live-Beacon: eigene Session für echte Freunde sichtbar machen
    // (nur bei Sichtbarkeit „friends" – Stealth bleibt lokal).
    if (visibility == SessionVisibility.friends) {
      final online = await _online();
      if (online != null) {
        final row = await _db.getMyActiveSession(me.id, now);
        if (row != null) unawaited(online.upsertSession(row));
      }
    }
    return BadgeEngine(_db).evaluate(me.id,
        onlineUserId: (await _online())?.currentUser?.id);
  }

  Future<void> endMySession() async {
    final me = await _me();
    final now = DateTime.now();
    final current = await _db.getMyActiveSession(me.id, now);
    if (current != null) {
      await _db.endSession(current.id, now);
      final online = await _online();
      if (online != null) unawaited(online.endSession(current.id));
    }
  }

  /// „Bin dabei!" auf die Session eines Freundes (lokal oder online).
  Future<List<BadgeDef>> joinSession(String sessionId) async {
    final me = await _me();
    if (isRemoteId(sessionId)) {
      final online = await _online();
      if (online != null) {
        unawaited(
            online.joinSession(stripRemote(sessionId), joined: true));
      }
    } else {
      await _db.joinSession(sessionId, me.id, ParticipantKind.joined);
    }
    return BadgeEngine(_db).evaluate(me.id,
        onlineUserId: (await _online())?.currentUser?.id);
  }

  /// Fern-Prost auf eine Session (lokal oder online).
  Future<void> toastSession(String sessionId) async {
    final me = await _me();
    if (isRemoteId(sessionId)) {
      final online = await _online();
      if (online != null) {
        unawaited(
            online.joinSession(stripRemote(sessionId), joined: false));
      }
    } else {
      await _db.joinSession(sessionId, me.id, ParticipantKind.toast);
    }
  }

  Future<List<BadgeDef>> toggleToast(String checkinId) async {
    final me = await _me();
    await _db.toggleToast(checkinId, me.id);
    return BadgeEngine(_db).evaluate(me.id,
        onlineUserId: (await _online())?.currentUser?.id);
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
    String? barcode,
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
      barcode: barcode,
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
