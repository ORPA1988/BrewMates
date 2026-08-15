import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../core/app_update.dart';
import '../core/config.dart';
import '../core/format.dart' show isUuid;
import '../domain/account_level.dart';
import '../domain/badges.dart';
import '../domain/challenges.dart';
import '../features/scan/barcode_lookup.dart';
import '../widgets/badge_celebration.dart';
import 'checkin_delete_queue.dart';
import 'community_sync.dart';
import 'db/database.dart';
import 'location_service.dart';
import 'restore.dart';
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
  // Gleiches Fenster wie der lokale Teil – „mehr laden" holt auch
  // serverseitig nach, statt bei den ersten 50 stehenzubleiben.
  return online.friendCheckins(limit: ref.watch(feedLimitProvider));
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

/// Grenzen der Beacon-Laufzeit. Kürzer als eine halbe Stunde ergibt keine
/// Einladung, länger als zwölf Stunden ist fast immer ein vergessener
/// Beacon — und ein Beacon, der aus Versehen stehen bleibt, ist ein
/// Datenschutzproblem, kein Komfortmerkmal. Beide Grenzen werden
/// serverseitig nochmals geprüft (Migration 0021).
const minSessionDuration = Duration(minutes: 30);
const maxSessionDuration = Duration(hours: 12);

/// Hält eine Laufzeit in den erlaubten Grenzen. Rein und testbar.
Duration clampSessionDuration(Duration d) {
  if (d < minSessionDuration) return minSessionDuration;
  if (d > maxSessionDuration) return maxSessionDuration;
  return d;
}

/// Zur Auswahl stehende Laufzeiten.
const sessionDurationChoices = <Duration>[
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 3),
  Duration(hours: 5),
  Duration(hours: 8),
  Duration(hours: 12),
];

/// Zuletzt gewählte Laufzeit — Vorgabe für den nächsten Beacon,
/// insbesondere für den Ein-Tap-Beacon, der nicht fragen soll.
/// Ohne eigene Wahl bleibt es bei drei Stunden wie bisher.
final preferredSessionDurationProvider =
    StateProvider<Duration>((ref) => const Duration(hours: 3));

/// Seitengröße für Feed und Tagebuch. Beide laden zunächst eine Seite und
/// erweitern das Fenster, sobald der Mensch ans Ende scrollt — ohne
/// Obergrenze würde jeder Check-in eines ganzen Bierlebens auf einmal
/// gelesen und gebaut.
const feedPageSize = 30;

/// Aktuelles Fenster des Feeds (wächst um [feedPageSize] je „mehr laden").
final feedLimitProvider = StateProvider<int>((ref) {
  // Neue Anmeldung = neuer Feed: Fenster zurücksetzen.
  ref.watch(onlineUserProvider);
  return feedPageSize;
});

/// Aktuelles Fenster des Tagebuchs.
final diaryLimitProvider = StateProvider<int>((ref) => feedPageSize);

/// Feed: abgemeldet = lokale Daten inkl. Demo-Freunde; angemeldet = eigene
/// lokale Check-ins + die echter Freunde (Demo-Inhalte verschwinden).
final feedProvider = StreamProvider<List<CheckinDetails>>((ref) {
  final db = ref.watch(databaseProvider);
  final limit = ref.watch(feedLimitProvider);
  if (!ref.watch(isSignedInProvider)) return db.watchFeed(limit: limit);
  final remote = ref.watch(remoteFeedProvider).valueOrNull ?? const [];
  return db.watchFeed(limit: limit).map((locals) {
    final merged = [
      ...locals.where((c) => c.author.isMe),
      ...remote.map(remoteCheckinToDetails),
    ]..sort((a, b) => b.checkin.createdAt.compareTo(a.checkin.createdAt));
    // Eigene und fremde Einträge kommen aus zwei Quellen mit je eigenem
    // Fenster – nach dem Mischen auf die Seitengröße stutzen, sonst
    // springt die Länge unvorhersehbar.
    return merged.length > limit ? merged.sublist(0, limit) : merged;
  });
});

/// Suchbegriff des Tagebuchs. Liegt im Provider statt im Bildschirm,
/// damit die Suche in die Abfrage wandern kann.
final diarySearchProvider = StateProvider<String>((ref) => '');

final myDiaryProvider = StreamProvider<List<CheckinDetails>>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchFeed(
        onlyProfileId: me.id,
        limit: ref.watch(diaryLimitProvider),
        search: ref.watch(diarySearchProvider),
      );
});

/// Gesamtzahl eigener Check-ins — für „alles geladen?" und Statistiken.
final myCheckinCountProvider = StreamProvider<int>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(0);
  return ref.watch(databaseProvider).watchCheckinCount(me.id);
});

/// Lokale Check-ins, die noch nicht im Online-Konto liegen – z. B. weil sie
/// offline entstanden sind (null = Status gerade nicht feststellbar).
final pendingCheckinUploadProvider =
    FutureProvider<List<CheckinDetails>?>((ref) async {
  if (!ref.watch(isSignedInProvider)) return null;
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return null;
  // Bewusst der ungekürzte Bestand, NICHT das Tagebuch-Fenster: Sonst
  // bliebe genau der alte, offline entstandene Check-in unentdeckt, für
  // den es den Assistenten gibt.
  final mine = await ref.watch(databaseProvider).myCheckinsDetailed(me.id);
  final candidates = [
    for (final d in mine)
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

// ============================================================================
// Gelöschte Check-ins nachtragen (eigene Warteschlange, siehe Funktion 19)
// ============================================================================

/// Überträgt lokal gelöschte Check-ins an den Server – im selben Takt wie
/// der Gasthaus-Abgleich, aber unabhängig davon. Die AppShell hält den
/// Provider am Leben. Rückgabe: übertragene Löschungen.
final checkinDeleteSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(_syncTickProvider);
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return 0;
  return replayCheckinDeleteQueue(
    ref.read(databaseProvider),
    deleteRemote: online.deleteCheckinRemote,
    deletePhoto: online.deleteCheckinPhoto,
  );
});

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
  // kIsWeb MUSS zuerst stehen: Im Browser meldet defaultTargetPlatform das
  // Betriebssystem des Geräts — auf Web gibt es aber kein APK-Update.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
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

/// 🏅 Datenpflege-Bestenliste (Top 20; leer offline/abgemeldet).
final leaderboardProvider = FutureProvider<
    List<({String username, String avatarEmoji, int points})>>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.contributionLeaderboard();
});

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

/// 👥 Eigene Crews (Beitritt per Einladungscode = Crew-UUID).
final myCrewsProvider = FutureProvider<List<RemoteCrew>>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return const [];
  return online.myCrews();
});

/// Mitglieder einer Crew (null = offline).
final crewMembersProvider = FutureProvider.autoDispose
    .family<List<({RemoteProfile profile, String role})>?, String>(
        (ref, crewId) async {
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;
  return online.crewMembers(crewId);
});

/// 🍺 Freunde mit aktiver Bierlaune (0018) — „X hätte jetzt Lust auf ein
/// Bier". Aktualisiert sich im 5-Minuten-Takt und nach eigenen Aktionen.
final thirstyFriendsProvider =
    FutureProvider<List<RemoteProfile>>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return const [];
  // Seit 0024 filtert der Server nach Freundeskreis: Bekannte sehen die
  // Bierlaune nicht. Vorher wurde die ganze Freundesliste geholt und in
  // der App gefiltert — die Angabe lag damit auf jedem Gerät, das
  // danach fragte.
  return online.thirstyFriends();
});

/// Eigene Bierlaune (kommt seit 0024 über eine Funktion, weil das
/// Spaltenrecht auf `thirsty_until` entzogen ist).
final myThirstyUntilProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(_syncTickProvider);
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  return online?.myThirstyUntil();
});

/// Merker, für welches Konto der Cloud-Restore diese App-Sitzung schon
/// vollständig gelaufen ist (verhindert Doppel-Läufe).
final _restoredUidProvider = StateProvider<String?>((_) => null);

/// ☁️ Cloud-Restore (Migration 0016): holt nach der Anmeldung eigene
/// Check-ins, Erfolge und Wunschliste vom Server zurück und vereinigt sie
/// mit dem lokalen Bestand — wichtig nach Neuinstallation/Gerätewechsel.
/// Läuft einmal pro Konto und App-Sitzung; solange er offline
/// unvollständig bleibt, versucht es der 5-Minuten-Takt erneut.
/// Die AppShell hält den Provider am Leben.
final cloudRestoreProvider = FutureProvider<RestoreSummary?>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  final user = ref.watch(onlineUserProvider).valueOrNull;
  if (online == null || user == null) return null;
  if (ref.read(_restoredUidProvider) == user.id) return null;
  final db = ref.read(databaseProvider);
  final summary = await restoreFromCloud(
    db,
    fetchCheckins: online.myRemoteCheckins,
    fetchBadges: online.myRemoteBadges,
    pushBadges: online.uploadBadges,
    fetchWishlist: online.myRemoteWishlist,
    pushWishlistItem: (key) => online.setWishlistRemote(key, add: true),
  );
  if (summary.complete) {
    ref.read(_restoredUidProvider.notifier).state = user.id;
  }
  if (summary.checkins > 0) {
    // Wiederhergestellte Check-ins können weitere Abzeichen auslösen.
    await ref.read(actionsProvider).evaluateBadges();
  }
  return summary;
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

/// Server-Check-in-UUID zu einer Feed-ID: `remote-…`-Präfix entfernen;
/// null, wenn der Eintrag nie hochgeladen wurde (Demo/Seed ohne UUID).
String? serverCheckinId(String feedId) {
  final real = stripRemote(feedId);
  return isUuid(real) ? real : null;
}

/// 🍻 Server-Reaktionen (Toasts + Kommentare) für alle Feed-Einträge in
/// EINER Abfrage – gilt für eigene hochgeladene Check-ins genauso wie für
/// die der Freunde. null = offline/abgemeldet (Karte fällt auf die
/// lokalen Zähler zurück); aktualisiert sich im 5-Minuten-Takt und nach
/// jeder eigenen Aktion (Invalidate in BrewActions).
final feedReactionsProvider = FutureProvider<
    Map<String, ({int toasts, bool toastedByMe, int comments})>?>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return null;
  final feed = await ref.watch(feedProvider.future);
  final ids = <String>[
    for (final d in feed)
      if (serverCheckinId(d.checkin.id) case final id?) id,
  ];
  return online.reactionsFor(ids);
});

/// Kommentare eines Server-Check-ins (für das Kommentar-Sheet).
final remoteCommentsProvider = FutureProvider.autoDispose.family<
    List<({RemoteProfile author, String body, DateTime createdAt})>?,
    String>((ref, checkinId) async {
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;
  return online.commentsRemote(checkinId);
});

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
    final earned = await BadgeEngine(_db)
        .evaluate(me.id, onlineUserId: online?.currentUser?.id);
    // Neue Erfolge best-effort in die Cloud spiegeln (0016) — schlägt das
    // fehl, holt der Restore-Abgleich sie beim nächsten Lauf nach.
    if (earned.isNotEmpty && online != null) {
      final now = DateTime.now().toUtc();
      await online.uploadBadges({for (final b in earned) b.slug: now});
    }
    return earned;
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
    int? volumeMl,
    String? photoUrl,
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
          volumeMl: Value(volumeMl),
          photoUrl: Value(photoUrl),
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
    // Neue Erfolge best-effort in die Cloud spiegeln (0016).
    if (badges.isNotEmpty && online != null) {
      final stamp = DateTime.now().toUtc();
      unawaited(
          online.uploadBadges({for (final b in badges) b.slug: stamp}));
    }
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

  /// Eigenen Check-in löschen: lokal sofort (auch offline), der Server
  /// erfährt es beim nächsten Abgleich.
  ///
  /// Gibt die gelöschte Zeile zurück, damit „Rückgängig" sie
  /// wiederherstellen kann — oder null, wenn es den Check-in nicht gibt
  /// oder er jemand anderem gehört.
  ///
  /// Bereits verdiente Abzeichen und abgeschlossene Challenges bleiben
  /// bestehen: Erreichtes rückwirkend abzuerkennen wäre die schlechtere
  /// Überraschung und lüde zum Missbrauch als Rückabwicklung ein.
  Future<Checkin?> deleteCheckin(String checkinId) async {
    final me = await _me();
    final row = await _db.findCheckin(checkinId);
    if (row == null || row.profileId != me.id) return null;
    await _db.deleteCheckinLocal(
      row.id,
      photoUrl: row.photoUrl,
      now: DateTime.now(),
    );
    return row;
  }

  /// Nimmt ein Löschen zurück.
  ///
  /// Lief der Abgleich in der Zwischenzeit bereits (Sekundenfenster), ist
  /// die Serverzeile weg — der Check-in lebt dann lokal weiter und wird
  /// vom Upload-Assistenten wieder hochgeladen.
  Future<void> restoreCheckin(Checkin row) async {
    await _db.cancelCheckinDelete(row.id);
    await _db.restoreCheckinRow(row);
  }

  /// Session starten („der eine Tap"). Gibt neu verdiente Abzeichen zurück.
  /// [venueName] darf fehlen (Beacon „unterwegs" mit reiner GPS-Position);
  /// [crewId] gehört zu `visibility == crew` (nur die Crew sieht den Beacon).
  Future<List<BadgeDef>> startSession({
    String? venueName,
    String? venueId,
    String? message,
    required SessionVisibility visibility,
    required Duration autoEnd,
    double? latitude,
    double? longitude,
    String? crewId,
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
          expiresAt: now.add(clampSessionDuration(autoEnd)),
          latitude: Value(latitude),
          longitude: Value(longitude),
        ));
    // Live-Beacon: eigene Session für Freunde bzw. die Crew sichtbar
    // machen (Stealth bleibt lokal; RLS erzwingt die Sichtbarkeit).
    if (visibility != SessionVisibility.private) {
      final online = await _online();
      if (online != null) {
        final row = await _db.getMyActiveSession(me.id, now);
        if (row != null) {
          unawaited(online.upsertSession(row, crewId: crewId));
        }
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

  /// Laufende eigene Session verlängern.
  ///
  /// Gerechnet wird ab **jetzt**, nicht ab dem bisherigen Ende: „noch zwei
  /// Stunden" ist das, was jemand meint, der um 22 Uhr im Wirtshaus sitzt
  /// und verlängert. Die Obergrenze [maxSessionDuration] gilt wie beim
  /// Start und wird serverseitig nochmals geprüft.
  ///
  /// Rückgabe: das neue Ende, oder null wenn keine Session läuft.
  Future<DateTime?> extendMySession(Duration by) async {
    final me = await _me();
    final now = DateTime.now();
    final current = await _db.getMyActiveSession(me.id, now);
    if (current == null) return null;
    final until = now.add(clampSessionDuration(by));
    await _db.setSessionExpiry(current.id, until);
    final online = await _online();
    if (online != null) {
      unawaited(online.updateSessionExpiry(current.id, until));
    }
    return until;
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

  /// 🍺 Bierlaune umschalten: an = 4 Stunden ab jetzt, aus = löschen.
  Future<void> setBierlaune({required bool on}) async {
    final online = await _online();
    if (online == null) return;
    await online.setBierlaune(
        on ? DateTime.now().add(const Duration(hours: 4)) : null);
    _ref.invalidate(myRemoteProfileProvider);
    _ref.invalidate(myThirstyUntilProvider);
    _ref.invalidate(thirstyFriendsProvider);
  }

  /// ⚡ One-Tap-Check-in: loggt das zuletzt getrunkene Bier erneut —
  /// Details (Bewertung, Foto, Notiz) lassen sich später im normalen
  /// Flow ergänzen. Gibt null zurück, wenn es noch keinen Check-in gibt,
  /// sonst (Biername, Feier-Einträge).
  Future<(String, List<CelebrationItem>)?> repeatLastCheckin() async {
    final me = await _me();
    final mine = await _db.myCheckinsDetailed(me.id);
    if (mine.isEmpty) return null;
    final last = mine.first;
    final earned = await createCheckin(
      beerId: last.beer.id,
      servingStyle: last.checkin.servingStyle,
    );
    return (last.beer.name, earned);
  }

  Future<List<BadgeDef>> toggleToast(String checkinId) async {
    final me = await _me();
    await _db.toggleToast(checkinId, me.id);
    return BadgeEngine(_db).evaluate(me.id,
        onlineUserId: (await _online())?.currentUser?.id);
  }

  /// Toast auf einem hochgeladenen Check-in (eigener oder von Freunden):
  /// Server ist die Wahrheit; lokal wird der Toast gespiegelt, damit
  /// Abzeichen („Prost-Meister") weiterzählen. Gibt neue Abzeichen zurück.
  Future<List<BadgeDef>> toggleServerToast(
    String feedId,
    String serverId, {
    required bool on,
  }) async {
    final online = await _online();
    if (online != null) {
      await online.setToastRemote(serverId, on: on);
      _ref.invalidate(feedReactionsProvider);
    }
    final me = await _me();
    await _db.toggleToast(feedId, me.id);
    return BadgeEngine(_db)
        .evaluate(me.id, onlineUserId: online?.currentUser?.id);
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

  /// Kommentar auf einem hochgeladenen Check-in (serverseitig).
  Future<String?> addServerComment(String serverId, String body) async {
    final online = await _online();
    if (online == null) return 'Keine Verbindung.';
    final error = await online.addCommentRemote(serverId, body);
    if (error == null) {
      _ref.invalidate(feedReactionsProvider);
      _ref.invalidate(remoteCommentsProvider(serverId));
    }
    return error;
  }

  Future<void> toggleWishlist(String beerId) async {
    final me = await _me();
    await _db.toggleWishlist(me.id, beerId, DateTime.now());
    // Server-Spiegel (0016, best effort) — beer_key ist die lokale Bier-ID.
    final online = await _online();
    if (online != null) {
      final onList = await _db.isWishlisted(me.id, beerId);
      await online.setWishlistRemote(beerId, add: onList);
    }
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
