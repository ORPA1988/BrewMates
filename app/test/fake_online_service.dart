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

  @override
  NotificationsApi get notifications => _notifications;

  late final _sessions = _FakeSessionsApi(this);
  late final _friends = _FakeFriendsApi(this);

  @override
  SessionsApi get sessions => _sessions;

  @override
  FriendsApi get friends => _friends;
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
  Future<List<String>> myActiveSessionIds() async {
    _fake.aufrufe.add('myActiveSessionIds');
    return List.of(_fake.aktiveSessionIds);
  }

  @override
  Future<bool> upsertSession(local.Session session, {String? crewId}) async {
    _fake.aufrufe.add('upsertSession:${session.id}');
    _fake.aktiveSessionIds.add(session.id);
    return true;
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
