import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brewmates/data/db/database.dart' as local;
import 'package:brewmates/data/online/online_service.dart';

/// Ein Client, der nie benutzt wird. Ihn zu konstruieren stellt keine
/// Verbindung her — die Attrappen antworten, bevor irgendetwas gesendet
/// würde.
SupabaseClient _blindClient() =>
    SupabaseClient('http://localhost:1', 'test-anon-key');

/// Test-Doppel für [OnlineService].
///
/// **Warum es das gibt:** Bis 2026-08-15 überschrieben alle Tests den
/// `onlineServiceProvider` mit `null` — der Zweig „Konto vorhanden" war
/// damit vollständig ungetestet. Genau dort schlich sich zweimal derselbe
/// Fehler ein: eine Bedingung vor dem Serveraufruf, die immer griff, so
/// dass der Aufruf nie stattfand und die App trotzdem Erfolg meldete
/// (siehe `session_id_test.dart`).
///
/// **Warum das nach der Aufteilung (B-3) weiter funktioniert:** Die
/// Bereiche sind normale Klassen, keine Extensions. Nur deshalb lassen sie
/// sich hier ableiten und überschreiben. Mit Extensions wäre der Aufruf
/// still an der Attrappe vorbeigegangen — die Tests hätten grün geleuchtet
/// und nichts mehr geprüft.
class FakeOnlineService extends OnlineService {
  FakeOnlineService() : super(_blindClient());

  /// Aufgezeichnete Aufrufe, in Reihenfolge — `methode:argument`.
  final List<String> aufrufe = [];

  /// Was der „Server" als laufende eigene Sessions führt.
  final List<String> aktiveSessionIds = [];

  /// Soll der nächste schreibende Aufruf scheitern?
  bool schlaegtFehl = false;

  List<RemoteProfile> freunde = const [];
  List<FriendRequest> anfragen = const [];
  List<RemoteProfile> blockierte = const [];

  /// Anfragen, die der Testnutzer selbst gestellt hat.
  List<OutgoingRequest> gestellteAnfragen = const [];

  /// Profile, die der „Server" per ID kennt — fuer den QR-Weg.
  Map<String, RemoteProfile> profileNachId = const {};

  /// Ein angemeldeter Nutzer muss vorgetäuscht werden: Die Provider
  /// prüfen `currentUser != null`, bevor sie überhaupt etwas versuchen.
  @override
  User? get currentUser => User(
        id: '11111111-1111-1111-1111-111111111111',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime(2026).toIso8601String(),
      );

  /// Was der „Server" an nutzererstellten Bieren zur Namenssuche liefert.
  List<RemoteBeer> serverBiere = const [];

  @override
  Future<List<RemoteBeer>> searchCommunityBeers(String query) async {
    aufrufe.add('searchCommunityBeers:$query');
    if (schlaegtFehl) return const [];
    final begriff = query.trim().toLowerCase();
    if (begriff.length < 2) return const [];
    return [
      for (final b in serverBiere)
        if (b.name.toLowerCase().contains(begriff)) b,
    ];
  }

  @override
  Future<bool> upsertBeerBarcode(String ean, String beerId,
      {int? volumeMl}) async {
    aufrufe.add('upsertBeerBarcode:$ean:$beerId');
    return !schlaegtFehl;
  }

  /// Muss aufgezeichnet werden, damit Tests belegen koennen, dass ein
  /// Bier **nicht** ein zweites Mal eingereicht wurde. Ohne diese
  /// Ueberschreibung liefe die Pruefung ins Leere und leuchtete immer
  /// gruen — das Fehlermuster, das dieses Projekt schon dreimal hatte.
  @override
  Future<String?> submitCommunityBeer({
    required String name,
    required String style,
    required String breweryName,
    String? country,
    String? city,
    double? abv,
    bool isAlcoholFree = false,
    String? description,
    String? barcode,
    Uint8List? photoBytes,
  }) async {
    aufrufe.add('submitCommunityBeer:$name');
    return schlaegtFehl ? 'Fehlgeschlagen' : null;
  }

  /// Steuerbarer Live-Kanal: Tests schieben hier Benachrichtigungen rein.
  final eingehend = StreamController<RemoteNotification>.broadcast();
  List<RemoteNotification> ungelesen = const [];

  late final _notifications = _FakeNotificationsApi(this);
  late final _devices = _FakeDevicesApi(this);

  @override
  DevicesApi get devices => _devices;

  @override
  NotificationsApi get notifications => _notifications;

  late final _checkins = _FakeCheckinsApi(this);
  late final _feedback = _FakeFeedbackApi(this);

  @override
  FeedbackApi get feedback => _feedback;

  /// Testphasen-Schalter, Meldungen und Roadmap des „Servers".
  bool feedbackAn = true;
  List<FeedbackItem> meineMeldungen = const [];
  List<RoadmapItem> roadmap = const [];
  /// Reaktionen anderer auf eigene Sessions: sessionId -> Teilnehmer.
  Map<String, List<RemoteParticipant>> teilnehmer = const {};

  @override
  CheckinsApi get checkins => _checkins;

  @override
  Future<bool> updateMyProfile({String? displayName, String? avatarEmoji}) async {
    aufrufe.add('updateMyProfile:${displayName ?? ''}:${avatarEmoji ?? ''}');
    return !schlaegtFehl;
  }

  @override
  Future<String?> resetPassword(String email) async {
    aufrufe.add('resetPassword:$email');
    return schlaegtFehl ? 'Keine Verbindung.' : null;
  }

  @override
  Future<bool> completeChallenge(String challengeId) async {
    aufrufe.add('completeChallenge:$challengeId');
    return !schlaegtFehl;
  }

  /// Crews, denen der Testnutzer beigetreten ist.
  final List<String> beigetreteneCrews = [];

  /// 🍺 Eigene Bierlaune, wie der „Server" sie kennt.
  DateTime? thirstyBis;

  /// Freunde mit Bierlaune (inkl. `thirstyUntil`).
  List<RemoteProfile> thirstyFreunde = const [];

  /// Laufende Beacons von Freunden, wie Realtime sie zuletzt schickte.
  List<RemoteSession> freundesSessions = const [];

  /// Vertrauensstufe des Testnutzers (4 = Moderator, 5 = Admin).
  ({int level, int points})? stufe = (level: 1, points: 0);

  @override
  Future<({int level, int points})?> myAccountLevelInfo() async {
    aufrufe.add('myAccountLevelInfo');
    return stufe;
  }

  /// Meldungen, die der „Server" fuer die Moderation fuehrt.
  List<ModerationReport> meldungen = const [];

  late final _moderation = _FakeModerationApi(this);

  @override
  ModerationApi get moderation => _moderation;

  @override
  Future<String?> joinCrew(String code) async {
    aufrufe.add('joinCrew:$code');
    if (schlaegtFehl) return 'Diesen Einladungscode gibt es nicht.';
    beigetreteneCrews.add(code);
    return null;
  }

  late final _sessions = _FakeSessionsApi(this);
  late final _friends = _FakeFriendsApi(this);

  @override
  SessionsApi get sessions => _sessions;

  @override
  FriendsApi get friends => _friends;
}

class _FakeFeedbackApi extends FeedbackApi {
  _FakeFeedbackApi(this._fake)
      : super(_fake.client, (() => _fake.currentUser));

  final FakeOnlineService _fake;

  @override
  Future<bool> enabled() async => _fake.feedbackAn;

  @override
  Future<String?> submit({
    required FeedbackKind kind,
    required String body,
    required String appVersion,
    required String platform,
  }) async {
    _fake.aufrufe.add('feedback.submit:${kind.name}:$body:$appVersion:$platform');
    if (_fake.schlaegtFehl) return 'Konnte nicht gesendet werden.';
    _fake.meineMeldungen = [
      FeedbackItem(
        id: 'fb-${_fake.meineMeldungen.length + 1}',
        kind: kind,
        body: body,
        status: FeedbackStatus.open,
        createdAt: DateTime(2026, 9, 3),
      ),
      ..._fake.meineMeldungen,
    ];
    return null;
  }

  @override
  Future<List<FeedbackItem>> mine() async => _fake.meineMeldungen;

  @override
  Future<List<RoadmapItem>> roadmap() async => _fake.roadmap;
}

class _FakeCheckinsApi extends CheckinsApi {
  _FakeCheckinsApi(this._fake)
      : super(_fake.client, (() => _fake.currentUser));

  final FakeOnlineService _fake;

  @override
  Future<bool> insertCheckin(local.CheckinDetails details) async {
    _fake.aufrufe.add('insertCheckin:${details.checkin.id}');
    return !_fake.schlaegtFehl;
  }

  @override
  Future<bool> setToastRemote(String checkinId, {required bool on}) async {
    _fake.aufrufe.add('setToastRemote:$checkinId:$on');
    return !_fake.schlaegtFehl;
  }

  @override
  Future<bool> uploadBadges(Map<String, DateTime> badges) async {
    _fake.aufrufe.add('uploadBadges:${badges.length}');
    return !_fake.schlaegtFehl;
  }
}

class _FakeSessionsApi extends SessionsApi {
  _FakeSessionsApi(this._fake)
      : super(_fake.client, (() => _fake.currentUser));

  final FakeOnlineService _fake;

  @override
  Future<bool> endSession(String sessionId) async {
    _fake.aufrufe.add('endSession:$sessionId');
    if (_fake.schlaegtFehl) return false;
    _fake.aktiveSessionIds.remove(sessionId);
    return true;
  }

  @override
  Future<bool> updateSessionExpiry(String sessionId, DateTime until) async {
    _fake.aufrufe.add('updateSessionExpiry:$sessionId');
    return !_fake.schlaegtFehl;
  }

  @override
  Stream<List<RemoteSession>> friendSessionsStream() =>
      Stream.value(_fake.freundesSessions);

  @override
  Future<List<String>> myActiveSessionIds() async {
    _fake.aufrufe.add('myActiveSessionIds');
    return List.of(_fake.aktiveSessionIds);
  }

  @override
  Future<List<Map<String, dynamic>>> myActiveSessions() async {
    _fake.aufrufe.add('myActiveSessions');
    final now = DateTime.now().toUtc();
    return [
      for (final id in _fake.aktiveSessionIds)
        {
          'id': id,
          'venue_id': null,
          'venue_name': 'Serverwirt',
          'message': null,
          'visibility': 'friends',
          'status': 'active',
          'started_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
          'expires_at': now.add(const Duration(hours: 2)).toIso8601String(),
          'ended_at': null,
          'latitude': null,
          'longitude': null,
        },
    ];
  }

  @override
  Future<bool> upsertSession(local.Session session, {String? crewId}) async {
    _fake.aufrufe.add('upsertSession:${session.id}');
    if (_fake.schlaegtFehl) return false;
    _fake.aktiveSessionIds.add(session.id);
    return true;
  }

  @override
  Future<bool> joinSession(String sessionId, {required bool joined}) async {
    _fake.aufrufe.add('joinSession:$sessionId:$joined');
    return !_fake.schlaegtFehl;
  }

  @override
  Future<List<RemoteParticipant>> participantsOf(String sessionId) async {
    _fake.aufrufe.add('participantsOf:$sessionId');
    return _fake.teilnehmer[sessionId] ?? const [];
  }
}

class _FakeDevicesApi extends DevicesApi {
  _FakeDevicesApi(this._fake)
      : super(_fake.client, (() => _fake.currentUser));

  final FakeOnlineService _fake;

  @override
  Future<bool> register(String token, {String platform = 'android'}) async {
    _fake.aufrufe.add('devices.register:$token');
    return !_fake.schlaegtFehl;
  }

  @override
  Future<bool> unregister(String token) async {
    _fake.aufrufe.add('devices.unregister:$token');
    return !_fake.schlaegtFehl;
  }
}

class _FakeNotificationsApi extends NotificationsApi {
  _FakeNotificationsApi(this._fake)
      : super(_fake.client, (() => _fake.currentUser));

  final FakeOnlineService _fake;

  @override
  Stream<RemoteNotification> incoming() => _fake.eingehend.stream;

  @override
  Future<List<RemoteNotification>> unread() async => _fake.ungelesen;

  @override
  Future<void> markRead(Iterable<String> ids) async {
    _fake.aufrufe.add('markRead:${ids.join(",")}');
  }
}

class _FakeFriendsApi extends FriendsApi {
  _FakeFriendsApi(this._fake)
      : super(_fake.client, (() => _fake.currentUser));

  final FakeOnlineService _fake;

  @override
  Future<RemoteProfile?> profileById(String profileId) async {
    _fake.aufrufe.add('profileById:$profileId');
    return _fake.profileNachId[profileId];
  }

  @override
  Future<String?> sendFriendRequest(String profileId) async {
    _fake.aufrufe.add('sendFriendRequest:$profileId');
    if (_fake.schlaegtFehl) return 'Anfrage fehlgeschlagen.';
    final ziel = _fake.profileNachId[profileId];
    if (ziel != null) {
      _fake.gestellteAnfragen = [
        ..._fake.gestellteAnfragen,
        OutgoingRequest(friendshipId: 'fs-$profileId', to: ziel),
      ];
    }
    return null;
  }

  @override
  Future<List<OutgoingRequest>> outgoingRequests() async {
    _fake.aufrufe.add('outgoingRequests');
    return _fake.gestellteAnfragen;
  }

  @override
  Future<bool> withdrawRequest(String friendshipId) async {
    _fake.aufrufe.add('withdrawRequest:$friendshipId');
    if (_fake.schlaegtFehl) return false;
    _fake.gestellteAnfragen = [
      for (final a in _fake.gestellteAnfragen)
        if (a.friendshipId != friendshipId) a,
    ];
    return true;
  }

  @override
  Future<List<RemoteProfile>> friends() async => _fake.freunde;

  @override
  Future<DateTime?> myThirstyUntil() async {
    _fake.aufrufe.add('myThirstyUntil');
    return _fake.thirstyBis;
  }

  @override
  Future<List<RemoteProfile>> thirstyFriends() async {
    _fake.aufrufe.add('thirstyFriends');
    return _fake.thirstyFreunde;
  }

  @override
  Future<List<FriendRequest>> incomingRequests() async {
    _fake.aufrufe.add('incomingRequests');
    return _fake.anfragen;
  }

  @override
  Future<List<RemoteProfile>> blockedProfiles() async => _fake.blockierte;

  @override
  Future<bool> setFriendTier(String profileId, FriendTier tier) async {
    _fake.aufrufe.add('setFriendTier:$profileId:${tier.name}');
    return !_fake.schlaegtFehl;
  }

  @override
  Future<bool> respondRequest(String friendshipId,
      {required bool accept}) async {
    _fake.aufrufe.add('respondRequest:$friendshipId:$accept');
    return !_fake.schlaegtFehl;
  }

  @override
  Future<bool> unblockProfile(String profileId) async {
    _fake.aufrufe.add('unblockProfile:$profileId');
    return !_fake.schlaegtFehl;
  }
}


class _FakeModerationApi extends ModerationApi {
  _FakeModerationApi(this._fake)
      : super(_fake.client, (() => _fake.currentUser));

  final FakeOnlineService _fake;

  @override
  Future<List<ModerationReport>> reports({String? status = 'open'}) async {
    _fake.aufrufe.add('moderation.reports:$status');
    if (status == null) return _fake.meldungen;
    return [
      for (final m in _fake.meldungen)
        if (m.status == status) m,
    ];
  }

  @override
  Future<bool> resolve(String reportId,
      {required String status, String? note}) async {
    _fake.aufrufe.add('moderation.resolve:$reportId:$status:${note ?? ''}');
    if (_fake.schlaegtFehl) return false;
    _fake.meldungen = [
      for (final m in _fake.meldungen)
        if (m.id == reportId)
          ModerationReport(
            id: m.id,
            subjectType: m.subjectType,
            reason: m.reason,
            status: status,
            createdAt: m.createdAt,
            reporterId: m.reporterId,
            reporterName: m.reporterName,
            reportedId: m.reportedId,
            reportedName: m.reportedName,
            note: note,
            handledAt: status == 'open' ? null : DateTime(2026, 9, 3),
            handledByName: status == 'open' ? null : 'mod',
          )
        else
          m,
    ];
    return true;
  }
}
