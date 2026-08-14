import 'dart:async';
import 'dart:typed_data';

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

/// Community-Bier aus der Supabase-Datenbank (per Barcode gefunden).
class RemoteBeer {
  const RemoteBeer({
    required this.name,
    required this.style,
    this.breweryName,
    this.breweryCountry,
    this.breweryCity,
    this.abv,
    this.isAlcoholFree = false,
    this.description,
    this.labelUrl,
    this.barcode,
  });

  final String name;
  final String style;
  final String? breweryName;
  final String? breweryCountry;
  final String? breweryCity;
  final double? abv;
  final bool isAlcoholFree;
  final String? description;
  final String? labelUrl;
  final String? barcode;
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
  // Blockieren & Melden (serverseitig durchgesetzt, Migration 0009)
  // --------------------------------------------------------------------------

  /// Blockiert ein Profil. Entfernt zugleich eine bestehende Freundschaft
  /// bzw. offene Anfrage in beide Richtungen; die Unsichtbarkeit von
  /// Sessions/Check-ins erzwingt danach die RLS serverseitig.
  Future<String?> blockProfile(String profileId) async {
    final me = currentUser;
    if (me == null) return 'Nicht angemeldet.';
    try {
      await _client.from('blocks').insert({
        'blocker_id': me.id,
        'blocked_id': profileId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') return 'Blockieren fehlgeschlagen.';
      // 23505 = war schon blockiert – Freundschaft trotzdem aufräumen.
    } catch (_) {
      return 'Keine Verbindung.';
    }
    try {
      await _client.from('friendships').delete().or(
          'and(requester_id.eq.${me.id},addressee_id.eq.$profileId),'
          'and(requester_id.eq.$profileId,addressee_id.eq.${me.id})');
    } catch (_) {}
    return null;
  }

  Future<void> unblockProfile(String profileId) async {
    final me = currentUser;
    if (me == null) return;
    try {
      await _client
          .from('blocks')
          .delete()
          .eq('blocker_id', me.id)
          .eq('blocked_id', profileId);
    } catch (_) {}
  }

  /// Eigene Blockliste (nur der Blockierende sieht sie – RLS).
  Future<List<RemoteProfile>> blockedProfiles() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await _client
          .from('blocks')
          .select('blocked:profiles!blocks_blocked_id_fkey($_profileCols)')
          .eq('blocker_id', me.id);
      return [
        for (final r in rows)
          RemoteProfile.fromRow(r['blocked'] as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Meldet ein Profil (Bearbeitung durch Admins im Admin-Bereich).
  Future<String?> reportProfile(String profileId, String reason) async {
    final me = currentUser;
    if (me == null) return 'Nicht angemeldet.';
    final trimmed = reason.trim();
    if (trimmed.length < 3) return 'Bitte begründe die Meldung kurz.';
    try {
      await _client.from('reports').insert({
        'reporter_id': me.id,
        'reported_id': profileId,
        'reason': trimmed,
      });
      return null;
    } catch (_) {
      return 'Melden fehlgeschlagen.';
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
        'venue_id': session.venueId,
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
        'venue_id': c.venueId,
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

  // --------------------------------------------------------------------------
  // Community-Bierdatenbank (Migration 0010): Nutzer tragen neue Biere mit
  // Foto + EAN direkt ein; die Community validiert über Check-ins („geloggt")
  // und „Kein Bier"-Meldungen.
  // --------------------------------------------------------------------------

  /// Bier per Barcode in der Community-DB suchen (nur angemeldet, RLS).
  Future<RemoteBeer?> communityBeerByBarcode(String ean) async {
    if (currentUser == null) return null;
    try {
      final row = await _client
          .from('beers')
          .select('name, style, abv, is_alcohol_free, description, '
              'label_url, barcode, brewery:breweries(name, country, city)')
          .eq('barcode', ean)
          .maybeSingle();
      if (row == null) return null;
      final brewery = row['brewery'] as Map<String, dynamic>?;
      return RemoteBeer(
        name: row['name'] as String,
        style: (row['style'] as String?) ?? 'Bier',
        breweryName: brewery?['name'] as String?,
        breweryCountry: brewery?['country'] as String?,
        breweryCity: brewery?['city'] as String?,
        abv: (row['abv'] as num?)?.toDouble(),
        isAlcoholFree: (row['is_alcohol_free'] as bool?) ?? false,
        description: row['description'] as String?,
        labelUrl: row['label_url'] as String?,
        barcode: row['barcode'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Neues Bier direkt in die Community-DB eintragen (unverifiziert; die
  /// Brauerei wird per Name wiederverwendet oder mit angelegt, das Foto
  /// landet im öffentlichen beer-photos-Bucket).
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
    final me = currentUser;
    if (me == null) return 'Nicht angemeldet.';
    try {
      String? breweryId;
      final existing = await _client
          .from('breweries')
          .select('id')
          .ilike('name', breweryName.trim())
          .maybeSingle();
      breweryId = existing?['id'] as String?;
      if (breweryId == null) {
        final inserted = await _client
            .from('breweries')
            .insert({
              'name': breweryName.trim(),
              'country': country?.trim(),
              'city': city?.trim(),
              'created_by': me.id,
            })
            .select('id')
            .single();
        breweryId = inserted['id'] as String;
      }

      String? photoUrl;
      if (photoBytes != null) {
        final path = '${me.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _client.storage.from('beer-photos').uploadBinary(
              path,
              photoBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        photoUrl = _client.storage.from('beer-photos').getPublicUrl(path);
      }

      await _client.from('beers').insert({
        'brewery_id': breweryId,
        'name': name.trim(),
        'style': style.trim(),
        'abv': abv,
        'is_alcohol_free': isAlcoholFree,
        'description':
            (description == null || description.trim().isEmpty)
                ? null
                : description.trim(),
        'label_url': photoUrl,
        'barcode': barcode,
        'created_by': me.id,
      });
      return null;
    } on StorageException {
      return 'Foto-Upload fehlgeschlagen – Bier bitte nochmal speichern.';
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return 'Diesen Barcode gibt es schon in der Community-DB.';
      }
      return 'Eintragen fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung.';
    }
  }

  /// „Kein Bier"-Meldung: true = gezählt. Übersteigen die Meldungen die
  /// geloggten Check-ins um ≥ 10, entfernt der Server den Eintrag.
  Future<bool> flagBeerNotABeer(String barcode) async {
    if (currentUser == null) return false;
    try {
      final result = await _client
          .rpc('flag_beer_by_barcode', params: {'p_barcode': barcode});
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Aggregierte echte Community-Bewertung (Ø + Anzahl) über die
  /// Online-Check-ins ALLER Nutzer – nur das Aggregat, keine Identitäten.
  Future<(double, int)?> beerRatingStats(
      String beerName, String? breweryName) async {
    if (currentUser == null) return null;
    try {
      final rows = await _client.rpc('beer_rating_stats', params: {
        'p_beer_name': beerName,
        'p_brewery_name': breweryName,
      });
      if (rows is! List || rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      final avg = (row['rating_avg'] as num?)?.toDouble();
      final count = (row['rating_count'] as num?)?.toInt() ?? 0;
      if (avg == null || count == 0) return null;
      return (avg, count);
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // Gasthäuser (gemeinsame Datenbank, Migration 0011). Online-first:
  // Supabase ist die Wahrheit, die App hält einen Drift-Cache für Karte,
  // Picker und Offline-Anzeige.
  // --------------------------------------------------------------------------

  static const _venueCols =
      'id, name, category, address, city, latitude, longitude, '
      'opening_hours, price_half_l, price_third_l, verified, created_by, '
      'updated_at';

  /// Venues seit [since] (Delta über updated_at); null = offline/abgemeldet.
  Future<List<Map<String, dynamic>>?> fetchVenues({DateTime? since}) async {
    if (currentUser == null) return null;
    try {
      var query = _client.from('venues').select(_venueCols);
      if (since != null) {
        query = query.gt('updated_at', since.toUtc().toIso8601String());
      }
      final rows = await query.order('updated_at', ascending: true).limit(500);
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Legt ein Gasthaus an. Rückgabe: (venueId, Fehlermeldung) – genau eines
  /// von beiden ist gesetzt.
  Future<(String?, String?)> createVenue({
    required String name,
    required String category,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    String? openingHours,
    double? priceHalfL,
    double? priceThirdL,
  }) async {
    final me = currentUser;
    if (me == null) return (null, 'Nicht angemeldet.');
    try {
      final row = await _client
          .from('venues')
          .insert({
            'name': name.trim(),
            'category': category,
            'address': _emptyToNull(address),
            'city': _emptyToNull(city),
            'latitude': latitude,
            'longitude': longitude,
            'opening_hours': _emptyToNull(openingHours),
            'price_half_l': priceHalfL,
            'price_third_l': priceThirdL,
            'created_by': me.id,
          })
          .select('id')
          .single();
      return (row['id'] as String, null);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return (null, 'Dieses Gasthaus gibt es in dem Ort schon.');
      }
      return (null, 'Anlegen fehlgeschlagen.');
    } catch (_) {
      return (null, 'Keine Verbindung – Gasthaus-Pflege braucht Internet.');
    }
  }

  /// Aktualisiert Felder eines Gasthauses; RLS entscheidet, ob erlaubt.
  Future<String?> updateVenue(String id, Map<String, dynamic> patch) async {
    if (currentUser == null) return 'Nicht angemeldet.';
    try {
      await _client.from('venues').update(patch).eq('id', id);
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        return 'Dafür reicht deine Vertrauensstufe noch nicht.';
      }
      if (e.code == '23505') {
        return 'Dieses Gasthaus gibt es in dem Ort schon.';
      }
      return 'Speichern fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung – Gasthaus-Pflege braucht Internet.';
    }
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  // --------------------------------------------------------------------------
  // Vertrauensstufen & Datenpflege (Migration 0013)
  // --------------------------------------------------------------------------

  /// Eigene Vertrauensstufe + Punktestand; null = offline/abgemeldet.
  Future<({int level, int points})?> myAccountLevelInfo() async {
    if (currentUser == null) return null;
    try {
      final rows = await _client.rpc('my_account_level_info');
      if (rows is! List || rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      return (
        level: (row['level'] as num?)?.toInt() ?? 1,
        points: (row['points'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Community-Bier (Supabase) bearbeiten; RLS/Level entscheiden.
  Future<String?> updateCommunityBeer(
      String barcode, Map<String, dynamic> patch) async {
    if (currentUser == null) return 'Nicht angemeldet.';
    try {
      await _client.from('beers').update(patch).eq('barcode', barcode);
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        return 'Dafür reicht deine Vertrauensstufe noch nicht '
            '(Stammgast ab 25 Punkten).';
      }
      return 'Online-Speichern fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung – lokal ist die Änderung gespeichert.';
    }
  }

  /// Änderungsverlauf eines Datensatzes (Audit-Log aus Migration 0013).
  Future<List<({String? username, String action, Map<String, dynamic> changes, DateTime createdAt})>>
      editHistory(String entity, String entityId, {int limit = 10}) async {
    if (currentUser == null) return const [];
    try {
      final rows = await _client
          .from('edit_log')
          .select('action, changes, created_at, '
              'profile:profiles!edit_log_profile_id_fkey(username)')
          .eq('entity', entity)
          .eq('entity_id', entityId)
          .order('created_at', ascending: false)
          .limit(limit);
      return [
        for (final r in rows)
          (
            username:
                (r['profile'] as Map<String, dynamic>?)?['username'] as String?,
            action: r['action'] as String,
            changes: (r['changes'] as Map<String, dynamic>?) ?? const {},
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // Challenges (Migration 0012): Admins legen sie an, alle sehen sie;
  // Abschlüsse sind für Freunde sichtbar.
  // --------------------------------------------------------------------------

  static const _challengeCols =
      'id, title, description, emoji, rule, starts_at, ends_at';

  /// Alle Challenges (aktive + vergangene); null = offline/abgemeldet.
  Future<List<Map<String, dynamic>>?> listChallenges() async {
    if (currentUser == null) return null;
    try {
      final rows = await _client
          .from('challenges')
          .select(_challengeCols)
          .order('ends_at', ascending: false)
          .limit(100);
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<String?> createChallenge({
    required String title,
    required String description,
    required String emoji,
    required Map<String, dynamic> rule,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final me = currentUser;
    if (me == null) return 'Nicht angemeldet.';
    try {
      await _client.from('challenges').insert({
        'title': title.trim(),
        'description': description.trim(),
        'emoji': emoji,
        'rule': rule,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'created_by': me.id,
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '42501') return 'Nur Admins können Challenges anlegen.';
      return 'Anlegen fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung.';
    }
  }

  Future<String?> deleteChallenge(String id) async {
    try {
      await _client.from('challenges').delete().eq('id', id);
      return null;
    } catch (_) {
      return 'Löschen fehlgeschlagen.';
    }
  }

  /// Abschluss melden. Seit Migration 0014 validiert der SERVER die Regel
  /// gegen die Online-Check-ins (direkte Inserts sind gesperrt) — ein
  /// manipulierter Client kann keine Abschlüsse mehr erfinden.
  Future<void> completeChallenge(String challengeId) async {
    if (currentUser == null) return;
    try {
      await _client
          .rpc('complete_challenge', params: {'p_challenge': challengeId});
    } catch (_) {}
  }

  /// 🏅 Datenpflege-Bestenliste (aggregierte Punkte, private Profile
  /// ausgenommen; nur Anzeige-Daten, keine IDs).
  Future<List<({String username, String avatarEmoji, int points})>>
      contributionLeaderboard({int limit = 20}) async {
    if (currentUser == null) return const [];
    try {
      final rows = await _client
          .rpc('contribution_leaderboard', params: {'p_limit': limit});
      return [
        for (final r in (rows as List).cast<Map<String, dynamic>>())
          (
            username: r['username'] as String,
            avatarEmoji: (r['avatar_emoji'] as String?) ?? '🍺',
            points: (r['points'] as num?)?.toInt() ?? 0,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Wer hat's geschafft? (RLS filtert auf mich + Freunde.)
  Future<List<RemoteProfile>> challengeCompletions(String challengeId) async {
    if (currentUser == null) return const [];
    try {
      final rows = await _client
          .from('challenge_completions')
          .select('profile:profiles!challenge_completions_profile_id_fkey'
              '($_profileCols)')
          .eq('challenge_id', challengeId);
      return [
        for (final r in rows)
          RemoteProfile.fromRow(r['profile'] as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // Upload-Assistent (Roadmap Stufe B): lokale Alt-Check-ins einmalig und
  // nachvollziehbar ins Konto übertragen. Idempotent per Upsert über die
  // clientseitig erzeugten UUIDs – mehrfaches Ausführen schadet nie.
  // --------------------------------------------------------------------------

  static final _uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Nur echte, in der App entstandene Check-ins sind übertragbar –
  /// Demo-/Seed-Einträge tragen keine UUID und bleiben lokal.
  static bool isUploadable(local.CheckinDetails details) =>
      _uuidPattern.hasMatch(details.checkin.id);

  /// Upsert-Zeile für einen lokalen Check-in (denormalisiert, identisch zum
  /// Live-Spiegeln in [insertCheckin]). Statisch und pur, damit der
  /// Assistent ohne Supabase testbar bleibt. null = nicht übertragbar.
  static Map<String, dynamic>? uploadRow(
      local.CheckinDetails details, String profileId) {
    if (!isUploadable(details)) return null;
    final c = details.checkin;
    return {
      'id': c.id,
      'profile_id': profileId,
      'session_id': null,
      'venue_id': c.venueId,
      'beer_name': details.beer.name,
      'brewery_name': details.brewery.name,
      'beer_style': details.beer.style,
      'is_alcohol_free': details.beer.isAlcoholFree,
      'rating': c.rating,
      'note': c.note,
      'venue_name': c.venueName,
      'visibility': 'friends',
      'created_at': c.createdAt.toUtc().toIso8601String(),
    };
  }

  /// IDs der eigenen Check-ins, die bereits online liegen
  /// (null = gerade nicht feststellbar, z. B. offline).
  Future<Set<String>?> myRemoteCheckinIds() async {
    final me = currentUser;
    if (me == null) return null;
    try {
      final rows =
          await _client.from('checkins').select('id').eq('profile_id', me.id);
      return {for (final r in rows) r['id'] as String};
    } catch (_) {
      return null;
    }
  }

  /// Überträgt die übergebenen Check-ins in Blöcken zu 50.
  /// Rückgabe: Anzahl übertragener Einträge, null bei Verbindungsfehler.
  Future<int?> uploadLocalCheckins(List<local.CheckinDetails> items) async {
    final me = currentUser;
    if (me == null) return null;
    final rows = [
      for (final d in items)
        if (uploadRow(d, me.id) case final row?) row,
    ];
    try {
      for (var i = 0; i < rows.length; i += 50) {
        await _client
            .from('checkins')
            .upsert(rows.sublist(i, i + 50 > rows.length ? rows.length : i + 50));
      }
      return rows.length;
    } catch (_) {
      return null;
    }
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
