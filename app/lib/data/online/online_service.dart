import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../db/database.dart' as local;

/// Profil eines echten Nutzers aus Supabase.
class RemoteProfile {
  const RemoteProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarEmoji,
    this.accountNo,
  });

  factory RemoteProfile.fromRow(Map<String, dynamic> row) => RemoteProfile(
        id: row['id'] as String,
        username: row['username'] as String,
        displayName: (row['display_name'] as String?) ?? row['username'] as String,
        avatarEmoji: (row['avatar_emoji'] as String?) ?? '🍺',
        accountNo: (row['account_no'] as num?)?.toInt(),
      );

  final String id;
  final String username;
  final String displayName;
  final String avatarEmoji;

  /// Unveränderliche, kurze Kontonummer (für Anzeige/Support). Die
  /// technische Konto-ID ist die UUID [id]; Anmeldeverfahren (E-Mail,
  /// Google …) hängen daran und sind änderbar.
  final int? accountNo;

  /// Platzhalter-Name aus der automatischen Kontoanlage (z. B. nach
  /// Google-Login) – Nutzer sollte sich umbenennen.
  bool get hasPlaceholderUsername => username.startsWith('mate_');
}

/// Eingehende Freundschaftsanfrage.
class FriendRequest {
  const FriendRequest({required this.friendshipId, required this.from});

  final String friendshipId;
  final RemoteProfile from;
}

/// Aktive Session eines Freundes.
class RemoteSession {
  const RemoteSession({
    required this.id,
    required this.host,
    this.venueName,
    this.message,
    this.latitude,
    this.longitude,
    required this.startedAt,
    required this.expiresAt,
  });

  final String id;
  final RemoteProfile host;
  final String? venueName;
  final String? message;
  final double? latitude;
  final double? longitude;
  final DateTime startedAt;
  final DateTime expiresAt;
}

/// Check-in eines Freundes (denormalisiert, ohne lokale Bier-FK).
class RemoteCheckin {
  const RemoteCheckin({
    required this.id,
    required this.author,
    required this.beerName,
    this.breweryName,
    this.beerStyle,
    this.isAlcoholFree = false,
    this.rating,
    this.note,
    this.venueName,
    this.sessionId,
    required this.createdAt,
  });

  final String id;
  final RemoteProfile author;
  final String beerName;
  final String? breweryName;
  final String? beerStyle;
  final bool isAlcoholFree;
  final double? rating;
  final String? note;
  final String? venueName;
  final String? sessionId;
  final DateTime createdAt;
}

/// Alle Supabase-Zugriffe der App. Grundsätze:
/// - Die App bleibt ohne Konto voll funktionsfähig (local-first).
/// - Netzfehler werden geschluckt, wo der lokale Zustand die Wahrheit ist
///   (Spiegel-Schreibvorgänge), und als Meldung zurückgegeben, wo der
///   Nutzer eine Antwort erwartet (Login, Anfragen).
class OnlineService {
  OnlineService(this._client);

  final SupabaseClient _client;

  static const _profileCols =
      'id, username, display_name, avatar_emoji, account_no';

  /// Deep-Link, über den OAuth-Anmeldungen in die App zurückkehren.
  static const oauthRedirect = 'de.brewmates.app://login-callback';

  static Future<OnlineService?> initialize() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.anonKey,
      );
      return OnlineService(Supabase.instance.client);
    } catch (_) {
      // Kein Plattform-Plugin (Tests) oder kaputte Konfiguration →
      // App läuft lokal weiter.
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // Auth
  // --------------------------------------------------------------------------

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  /// Registrieren + Profil anlegen. Gibt null bei Erfolg zurück, sonst eine
  /// verständliche Fehlermeldung. `needsEmailConfirmation` über Rückgabewert
  /// 'confirm' signalisiert.
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required String avatarEmoji,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(cleanUsername)) {
      return 'Der Nutzername braucht 3–30 Zeichen: Kleinbuchstaben, '
          'Ziffern oder _';
    }
    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('username', cleanUsername)
          .maybeSingle();
      if (existing != null) return 'Dieser Nutzername ist schon vergeben.';

      final response =
          await _client.auth.signUp(email: email.trim(), password: password);
      final user = response.user;
      if (user == null) return 'Registrierung fehlgeschlagen – bitte erneut versuchen.';

      if (response.session != null) {
        await _upsertMyProfile(
            username: cleanUsername,
            displayName: displayName,
            avatarEmoji: avatarEmoji);
        return null;
      }
      // E-Mail-Bestätigung nötig: Profil wird beim ersten Login angelegt.
      return 'confirm';
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (_) {
      return 'Keine Verbindung – bitte später erneut versuchen.';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
    String? pendingUsername,
    String? pendingDisplayName,
    String? pendingEmoji,
  }) async {
    try {
      await _client.auth
          .signInWithPassword(email: email.trim(), password: password);
      // Profil sicherstellen (z. B. nach E-Mail-Bestätigung).
      final profile = await myProfile();
      if (profile == null) {
        await _upsertMyProfile(
          username: pendingUsername ??
              'brau_${_client.auth.currentUser!.id.substring(0, 6)}',
          displayName: pendingDisplayName ?? 'BrewMate',
          avatarEmoji: pendingEmoji ?? '🍺',
        );
      }
      return null;
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (_) {
      return 'Keine Verbindung – bitte später erneut versuchen.';
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Anmeldung/Registrierung mit dem Google-Konto (Browser-OAuth-Flow;
  /// die Rückkehr in die App läuft über [oauthRedirect]). Das Profil
  /// entsteht serverseitig automatisch (Trigger) mit Platzhalter-Username.
  Future<String?> signInWithGoogle() async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: oauthRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return launched ? null : 'Google-Anmeldung konnte nicht gestartet werden.';
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('not enabled')) {
        return 'Google-Login ist serverseitig noch nicht freigeschaltet – '
            'nutze vorerst E-Mail + Passwort.';
      }
      return 'Google-Anmeldung fehlgeschlagen: ${e.message}';
    } catch (_) {
      return 'Keine Verbindung – bitte später erneut versuchen.';
    }
  }

  /// Nutzername ändern – frei wählbar, aber global nur einmal vergeben.
  /// Die Kontonummer/Konto-ID bleibt dabei unverändert.
  Future<String?> updateUsername(String username) async {
    final clean = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(clean)) {
      return 'Der Nutzername braucht 3–30 Zeichen: Kleinbuchstaben, '
          'Ziffern oder _';
    }
    try {
      await _client
          .from('profiles')
          .update({'username': clean}).eq('id', currentUser!.id);
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'Dieser Nutzername ist schon vergeben.';
      return 'Änderung fehlgeschlagen – bitte erneut versuchen.';
    } catch (_) {
      return 'Keine Verbindung – bitte später erneut versuchen.';
    }
  }

  String _authMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login')) {
      return 'E-Mail oder Passwort stimmt nicht.';
    }
    if (msg.contains('already registered')) {
      return 'Diese E-Mail ist schon registriert – melde dich an.';
    }
    if (msg.contains('password')) {
      return 'Das Passwort braucht mindestens 6 Zeichen.';
    }
    if (msg.contains('confirm')) {
      return 'Bitte bestätige zuerst deine E-Mail (Posteingang prüfen).';
    }
    return 'Anmeldung fehlgeschlagen: ${e.message}';
  }

  Future<void> _upsertMyProfile({
    required String username,
    required String displayName,
    required String avatarEmoji,
  }) async {
    await _client.from('profiles').upsert({
      'id': _client.auth.currentUser!.id,
      'username': username,
      'display_name': displayName,
      'avatar_emoji': avatarEmoji,
    });
  }

  Future<RemoteProfile?> myProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select(_profileCols)
          .eq('id', user.id)
          .maybeSingle();
      return row == null ? null : RemoteProfile.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // Rollen & Funktionen (Admin-Modell)
  // --------------------------------------------------------------------------

  /// Rolle eines Nutzers ('admin' | 'moderator' | null). RLS: eigene Rolle
  /// sieht jeder, fremde nur Admins.
  Future<String?> roleOf(String profileId) async {
    try {
      final row = await _client
          .from('user_roles')
          .select('role')
          .eq('profile_id', profileId)
          .maybeSingle();
      return row?['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> amIAdmin() async {
    final me = currentUser;
    if (me == null) return false;
    return await roleOf(me.id) == 'admin';
  }

  /// Freigeschaltete Funktionen eines Nutzers (z. B. premium, moderation).
  Future<Map<String, bool>> featuresOf(String profileId) async {
    try {
      final rows = await _client
          .from('user_features')
          .select('feature, enabled')
          .eq('profile_id', profileId);
      return {
        for (final r in rows) r['feature'] as String: r['enabled'] as bool,
      };
    } catch (_) {
      return const {};
    }
  }

  /// Admin: Rolle setzen (null = entziehen). Serverseitig via RLS auf
  /// Admins beschränkt – der Client-Aufruf allein genügt nie.
  Future<String?> adminSetRole(String profileId, String? role) async {
    try {
      if (role == null) {
        await _client
            .from('user_roles')
            .delete()
            .eq('profile_id', profileId);
      } else {
        await _client.from('user_roles').upsert({
          'profile_id': profileId,
          'role': role,
          'granted_by': currentUser?.id,
        });
      }
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '42501') return 'Nur Admins dürfen Rollen vergeben.';
      return 'Rollenänderung fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung.';
    }
  }

  /// Admin: Funktion für einen Nutzer aktivieren/deaktivieren.
  Future<String?> adminSetFeature(
      String profileId, String feature, bool enabled) async {
    final clean = feature.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{2,40}$').hasMatch(clean)) {
      return 'Funktionsname: 2–40 Zeichen, a–z, 0–9, _';
    }
    try {
      await _client.from('user_features').upsert({
        'profile_id': profileId,
        'feature': clean,
        'enabled': enabled,
        'granted_by': currentUser?.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '42501') return 'Nur Admins dürfen Funktionen schalten.';
      return 'Änderung fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung.';
    }
  }

  // --------------------------------------------------------------------------
  // Freunde
  // --------------------------------------------------------------------------

  Future<List<RemoteProfile>> searchProfiles(String query) async {
    final term = query.trim().toLowerCase();
    if (term.length < 3) return const [];
    try {
      final rows = await _client
          .from('profiles')
          .select(_profileCols)
          .ilike('username', '$term%')
          .neq('id', currentUser?.id ?? '')
          .limit(10);
      return [for (final r in rows) RemoteProfile.fromRow(r)];
    } catch (_) {
      return const [];
    }
  }

  Future<String?> sendFriendRequest(String profileId) async {
    try {
      await _client.from('friendships').insert({
        'requester_id': currentUser!.id,
        'addressee_id': profileId,
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'Anfrage läuft schon oder ihr seid Freunde.';
      return 'Anfrage fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung.';
    }
  }

  Future<List<FriendRequest>> incomingRequests() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await _client
          .from('friendships')
          .select('id, requester:profiles!friendships_requester_id_fkey($_profileCols)')
          .eq('addressee_id', me.id)
          .eq('status', 'pending');
      return [
        for (final r in rows)
          FriendRequest(
            friendshipId: r['id'] as String,
            from: RemoteProfile.fromRow(
                r['requester'] as Map<String, dynamic>),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> respondRequest(String friendshipId, {required bool accept}) async {
    try {
      if (accept) {
        await _client
            .from('friendships')
            .update({'status': 'accepted'}).eq('id', friendshipId);
      } else {
        await _client.from('friendships').delete().eq('id', friendshipId);
      }
    } catch (_) {}
  }

  Future<List<RemoteProfile>> friends() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await _client
          .from('friendships')
          .select('requester:profiles!friendships_requester_id_fkey($_profileCols), '
              'addressee:profiles!friendships_addressee_id_fkey($_profileCols)')
          .eq('status', 'accepted')
          .or('requester_id.eq.${me.id},addressee_id.eq.${me.id}');
      return [
        for (final r in rows)
          RemoteProfile.fromRow((r['requester'] as Map<String, dynamic>)['id'] == me.id
              ? r['addressee'] as Map<String, dynamic>
              : r['requester'] as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // Sessions (Live-Beacon)
  // --------------------------------------------------------------------------

  /// Eigene Session online spiegeln (Fehler still: lokal gilt weiter).
  Future<void> upsertSession(local.Session session) async {
    final me = currentUser;
    if (me == null) return;
    try {
      await _client.from('sessions').upsert({
        'id': session.id,
        'host_id': me.id,
        'venue_name': session.venueName,
        'message': session.message,
        'visibility': 'friends',
        'status': session.status.name,
        'started_at': session.startedAt.toUtc().toIso8601String(),
        'expires_at': session.expiresAt.toUtc().toIso8601String(),
        'ended_at': session.endedAt?.toUtc().toIso8601String(),
        'latitude': session.latitude,
        'longitude': session.longitude,
      });
    } catch (_) {}
  }

  Future<void> endSession(String sessionId) async {
    try {
      await _client.from('sessions').update({
        'status': 'ended',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);
    } catch (_) {}
  }

  /// Aktive Sessions der Freunde. Realtime-Stream; RLS filtert serverseitig
  /// auf sichtbare (aktive, befreundete) Sessions.
  Stream<List<RemoteSession>> friendSessionsStream() async* {
    final me = currentUser;
    if (me == null) {
      yield const [];
      return;
    }
    final profiles = <String, RemoteProfile>{};
    await for (final rows in _client
        .from('sessions')
        .stream(primaryKey: ['id']).order('started_at')) {
      final result = <RemoteSession>[];
      final now = DateTime.now().toUtc();
      for (final row in rows) {
        if (row['host_id'] == me.id) continue;
        if (row['status'] != 'active') continue;
        final expires = DateTime.parse(row['expires_at'] as String);
        if (!expires.isAfter(now)) continue;
        final hostId = row['host_id'] as String;
        final host = profiles[hostId] ??= await _fetchProfile(hostId);
        result.add(RemoteSession(
          id: row['id'] as String,
          host: host,
          venueName: row['venue_name'] as String?,
          message: row['message'] as String?,
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
          startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
          expiresAt: expires.toLocal(),
        ));
      }
      yield result;
    }
  }

  Future<RemoteProfile> _fetchProfile(String id) async {
    try {
      final row = await _client
          .from('profiles')
          .select(_profileCols)
          .eq('id', id)
          .maybeSingle();
      if (row != null) return RemoteProfile.fromRow(row);
    } catch (_) {}
    return RemoteProfile(
        id: id, username: 'unbekannt', displayName: 'BrewMate', avatarEmoji: '🍺');
  }

  /// Anzahl aktiver Sessions von NICHT-Freunden im Kartenausschnitt.
  /// Serverseitige Aggregatfunktion – liefert nur eine Zahl, nie Positionen.
  Future<int> countOtherActiveSessions({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    if (currentUser == null) return 0;
    try {
      final result =
          await _client.rpc<dynamic>('count_other_active_sessions', params: {
        'min_lat': minLat,
        'min_lng': minLng,
        'max_lat': maxLat,
        'max_lng': maxLng,
      });
      return (result as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> joinSession(String sessionId, {required bool joined}) async {
    final me = currentUser;
    if (me == null) return;
    try {
      await _client.from('session_participants').upsert({
        'session_id': sessionId,
        'profile_id': me.id,
        'kind': joined ? 'joined' : 'toast',
      });
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Check-ins
  // --------------------------------------------------------------------------

  /// Eigenen Check-in online spiegeln (denormalisiert).
  Future<void> insertCheckin(local.CheckinDetails details) async {
    final me = currentUser;
    if (me == null) return;
    final c = details.checkin;
    try {
      await _client.from('checkins').upsert({
        'id': c.id,
        'profile_id': me.id,
        'session_id': null,
        'beer_name': details.beer.name,
        'brewery_name': details.brewery.name,
        'beer_style': details.beer.style,
        'is_alcohol_free': details.beer.isAlcoholFree,
        'rating': c.rating,
        'note': c.note,
        'venue_name': c.venueName,
        'visibility': 'friends',
        'created_at': c.createdAt.toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<List<RemoteCheckin>> friendCheckins({int limit = 50}) async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await _client
          .from('checkins')
          .select('id, beer_name, brewery_name, beer_style, is_alcohol_free, '
              'rating, note, venue_name, session_id, created_at, '
              'author:profiles!checkins_profile_id_fkey($_profileCols)')
          .neq('profile_id', me.id)
          .order('created_at', ascending: false)
          .limit(limit);
      return [for (final r in rows) _checkinFromRow(r)];
    } catch (_) {
      return const [];
    }
  }

  RemoteCheckin _checkinFromRow(Map<String, dynamic> r) => RemoteCheckin(
        id: r['id'] as String,
        author:
            RemoteProfile.fromRow(r['author'] as Map<String, dynamic>),
        beerName: (r['beer_name'] as String?) ?? 'Unbekanntes Bier',
        breweryName: r['brewery_name'] as String?,
        beerStyle: r['beer_style'] as String?,
        isAlcoholFree: (r['is_alcohol_free'] as bool?) ?? false,
        rating: (r['rating'] as num?)?.toDouble(),
        note: r['note'] as String?,
        venueName: r['venue_name'] as String?,
        sessionId: r['session_id'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );
}
