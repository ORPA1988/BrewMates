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
import '../core/min_version.dart';
import '../core/format.dart' show isUuid;
import '../domain/account_level.dart';
import '../domain/badges.dart';
import '../domain/challenges.dart';
import '../features/scan/barcode_lookup.dart';
import '../widgets/badge_celebration.dart';
import 'badge_engine.dart';
import 'challenge_engine.dart';
import 'checkin_delete_queue.dart';
import 'community_sync.dart';
import 'db/database.dart';
import 'location_service.dart';
import 'restore.dart';
import 'venue_sync.dart';
import 'online/online_service.dart';
import 'push/push_service.dart';
import 'online/remote_mapping.dart';

// Aufgeteilt nach Themen (Backlog B-4). Reihenfolge alphabetisch.
part 'providers/beers.dart';
part 'providers/challenges.dart';
part 'providers/entdecken.dart';
part 'providers/feed.dart';
part 'providers/glocke.dart';
part 'providers/online.dart';
part 'providers/push.dart';
part 'providers/sessions.dart';
part 'providers/venues.dart';
part 'providers/wartung.dart';


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
      await online.checkins.uploadBadges({for (final b in earned) b.slug: now});
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
          unawaited(online.checkins.insertCheckin(details));
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
          online.checkins.uploadBadges({for (final b in badges) b.slug: stamp}));
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

  /// Einen eigenen Check-in korrigieren (Funktion 27).
  ///
  /// Wirkt sofort lokal; die Übertragung übernimmt der reguläre Abgleich
  /// über das `dirty`-Flag. Rückgabe: ob es der eigene Check-in war —
  /// fremde lehnt schon der Server ab, aber die App soll gar nicht erst
  /// so tun.
  ///
  /// Das Bier bleibt unverändert. Ein anderes Bier wäre ein anderer
  /// Check-in, keine Korrektur.
  Future<bool> editCheckin(
    String checkinId, {
    double? rating,
    String? note,
    bool clearNote = false,
    List<String>? flavorTags,
    ServingStyle? servingStyle,
    bool clearServingStyle = false,
    int? volumeMl,
    bool clearVolume = false,
    String? venueName,
    String? venueId,
    bool clearVenue = false,
  }) async {
    final me = await _me();
    final row = await _db.findCheckin(checkinId);
    if (row == null || row.profileId != me.id) return false;
    await _db.updateCheckinLocal(
      checkinId,
      rating: rating,
      note: note,
      clearNote: clearNote,
      flavorTags: flavorTags?.join(','),
      servingStyle: servingStyle,
      clearServingStyle: clearServingStyle,
      volumeMl: volumeMl,
      clearVolume: clearVolume,
      venueName: venueName,
      venueId: venueId,
      clearVenue: clearVenue,
    );
    return true;
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
          unawaited(online.sessions.upsertSession(row, crewId: crewId));
        }
      }
    }
    return BadgeEngine(_db).evaluate(me.id,
        onlineUserId: (await _online())?.currentUser?.id);
  }

  /// Eigenen Beacon beenden.
  ///
  /// Rückgabe: ob der Server es mitbekommen hat. Lokal ist der Beacon
  /// sofort aus — aber gesehen wird er über den Server. Bleibt er dort
  /// stehen, zeigt er Freunden weiter den Aufenthaltsort, bis der
  /// serverseitige Cron ihn beim Ablaufdatum schließt. Das kann Stunden
  /// dauern, also darf die App darüber nicht schweigen.
  ///
  /// null = es lief gar keine Session.
  Future<bool?> endMySession() async {
    final me = await _me();
    final now = DateTime.now();
    final current = await _db.getMyActiveSession(me.id, now);
    if (current == null) return null;
    await _db.endSession(current.id, now);
    final online = await _online();
    if (online == null) return true;
    return online.sessions.endSession(current.id);
  }

  /// Laufende eigene Session verlängern.
  ///
  /// Gerechnet wird ab **jetzt**, nicht ab dem bisherigen Ende: „noch zwei
  /// Stunden" ist das, was jemand meint, der um 22 Uhr im Wirtshaus sitzt
  /// und verlängert. Die Obergrenze [maxSessionDuration] gilt wie beim
  /// Start und wird serverseitig nochmals geprüft.
  ///
  /// Rückgabe: das neue Ende und ob der Server es übernommen hat, oder
  /// null wenn keine Session läuft.
  ///
  /// [synced] wird nicht verschwiegen: Lokal ist der Beacon sofort
  /// verlängert, aber gesehen wird er von Freunden über den Server. Ohne
  /// Verbindung zeigt deren Karte weiter das alte Ende — wer glaubt, er
  /// sei noch sichtbar, sitzt sonst vergeblich im Wirtshaus.
  Future<({DateTime until, bool synced})?> extendMySession(Duration by) async {
    final me = await _me();
    final now = DateTime.now();
    final current = await _db.getMyActiveSession(me.id, now);
    if (current == null) return null;
    final until = now.add(clampSessionDuration(by));
    await _db.setSessionExpiry(current.id, until);
    final online = await _online();
    // Ohne Konto gibt es keinen Server-Zwilling — das ist kein Fehlschlag.
    //
    // Hier stand einmal zusätzlich `!isRemoteId(current.id)`. Das war
    // falsch: `remote-` tragen nur FREMDE Sessions, die eigene ID ist eine
    // blanke UUID. Die Bedingung griff also immer und der Serveraufruf
    // unterblieb vollständig — das Verlängern kam nie an, meldete aber
    // Erfolg. Siehe `session_id_test.dart`.
    if (online == null) return (until: until, synced: true);
    final synced = await online.sessions.updateSessionExpiry(current.id, until);
    return (until: until, synced: synced);
  }

  /// „Bin dabei!" auf die Session eines Freundes (lokal oder online).
  Future<List<BadgeDef>> joinSession(String sessionId) async {
    final me = await _me();
    if (isRemoteId(sessionId)) {
      final online = await _online();
      if (online != null) {
        unawaited(
            online.sessions.joinSession(stripRemote(sessionId), joined: true));
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
            online.sessions.joinSession(stripRemote(sessionId), joined: false));
      }
    } else {
      await _db.joinSession(sessionId, me.id, ParticipantKind.toast);
    }
  }

  /// 🍺 Bierlaune umschalten: an = 4 Stunden ab jetzt, aus = löschen.
  /// Rückgabe: ob es beim Server angekommen ist. Eine Bierlaune, die
  /// niemand sieht, ist keine — darum wird ein Fehlschlag gemeldet
  /// statt stillschweigend als Erfolg dargestellt.
  Future<bool> setBierlaune({required bool on}) async {
    final online = await _online();
    if (online == null) return false;
    final ok = await online.friends.setBierlaune(
        on ? DateTime.now().add(const Duration(hours: 4)) : null);
    _ref.invalidate(myRemoteProfileProvider);
    _ref.invalidate(myThirstyUntilProvider);
    _ref.invalidate(thirstyFriendsProvider);
    return ok;
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
      await online.checkins.setToastRemote(serverId, on: on);
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
    final error = await online.checkins.addCommentRemote(serverId, body);
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
      await online.checkins.setWishlistRemote(beerId, add: onList);
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
