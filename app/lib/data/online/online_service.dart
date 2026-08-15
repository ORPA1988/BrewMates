import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
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
    this.thirstyUntil,
  });

  factory RemoteProfile.fromRow(Map<String, dynamic> row) => RemoteProfile(
        id: row['id'] as String,
        username: row['username'] as String,
        displayName: (row['display_name'] as String?) ?? row['username'] as String,
        avatarEmoji: (row['avatar_emoji'] as String?) ?? '🍺',
        accountNo: (row['account_no'] as num?)?.toInt(),
        thirstyUntil: row['thirsty_until'] == null
            ? null
            : DateTime.parse(row['thirsty_until'] as String).toLocal(),
      );

  final String id;
  final String username;
  final String displayName;
  final String avatarEmoji;

  /// 🍺 Bierlaune (0018): bis wann Lust auf ein Bier signalisiert wird.
  final DateTime? thirstyUntil;

  bool get hasBierlaune =>
      thirstyUntil != null && thirstyUntil!.isAfter(DateTime.now());

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
    this.photoUrl,
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
  final String? photoUrl;
  final DateTime createdAt;
}

/// 👥 Crew (Gruppe) aus Supabase — Beitritt per Einladungscode (UUID).
class RemoteCrew {
  const RemoteCrew({
    required this.id,
    required this.name,
    required this.emoji,
    required this.ownerId,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String emoji;
  final String ownerId;
  final int memberCount;
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
      'id, username, display_name, avatar_emoji, account_no, thirsty_until';

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

  /// Konto unwiderruflich löschen (0017): entfernt Profil, alle
  /// Server-Daten (FK-Kaskaden) und den Auth-Nutzer; Community-Beiträge
  /// werden anonymisiert. Lokale Daten auf dem Gerät bleiben.
  /// null = ok (danach abgemeldet), sonst Fehlermeldung.
  Future<String?> deleteMyAccount() async {
    if (currentUser == null) return 'Nicht angemeldet.';
    try {
      await _client.rpc('delete_my_account');
      await _client.auth.signOut();
      return null;
    } catch (_) {
      return 'Löschen fehlgeschlagen – bitte später erneut versuchen.';
    }
  }

  /// Anmeldung/Registrierung mit dem Google-Konto (Browser-OAuth-Flow;
  /// die Rückkehr in die App läuft über [oauthRedirect]). Das Profil
  /// entsteht serverseitig automatisch (Trigger) mit Platzhalter-Username.
  Future<String?> signInWithGoogle() async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        // Web: zurück auf die eigene Seiten-URL (GitHub Pages), sonst
        // Custom-Scheme in die App; supabase_flutter erkennt den
        // PKCE-Code in der Rück-URL automatisch.
        redirectTo:
            kIsWeb ? Uri.base.origin + Uri.base.path : oauthRedirect,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
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
    // Ohne Session keine Suche — und vor allem kein `neq('id', '')`,
    // das serverseitig als ungültige UUID abbricht (still gefangen =
    // „keine Treffer", obwohl nur die Anmeldung fehlte).
    final myId = currentUser?.id;
    if (myId == null) return const [];
    // %, Komma und Klammern würden die PostgREST-or()-Syntax bzw. das
    // LIKE-Muster kapern — in Nutzernamen/Anzeigenamen sind sie eh tabu.
    final safe = term.replaceAll(RegExp(r'[%,()\\]'), '');
    if (safe.length < 3) return const [];
    try {
      // Nutzername als Präfix, Anzeigename als Teilstring: Konten aus
      // Google-Login/E-Mail-Registrierung tragen den echten Namen oft nur
      // im display_name (bis 0019 war der username immer mate_<hex>).
      final rows = await _client
          .from('profiles')
          .select(_profileCols)
          .or('username.ilike.$safe%,display_name.ilike.%$safe%')
          .neq('id', myId)
          .order('username', ascending: true)
          .limit(10);
      return [for (final r in rows) RemoteProfile.fromRow(r)];
    } catch (_) {
      return const [];
    }
  }

  /// Ein einzelnes Profil über seine ID holen — für den QR-Scan, der eine
  /// ID statt eines Suchbegriffs liefert.
  ///
  /// Null bedeutet: gibt es nicht, ist für uns nicht sichtbar (blockiert,
  /// privat) oder wir sind offline. Der Aufrufer sagt in allen Fällen
  /// dasselbe — mehr Auskunft wäre hier eine Auskunft über Fremde.
  Future<RemoteProfile?> profileById(String profileId) async {
    if (currentUser == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select(_profileCols)
          .eq('id', profileId)
          .maybeSingle();
      return row == null ? null : RemoteProfile.fromRow(row);
    } catch (_) {
      return null;
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

  /// 🍺 Bierlaune setzen (bis [until]) oder beenden (null).
  Future<void> setBierlaune(DateTime? until) async {
    final me = currentUser;
    if (me == null) return;
    try {
      await _client.from('profiles').update({
        'thirsty_until': until?.toUtc().toIso8601String(),
      }).eq('id', me.id);
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
  // Crews (Gruppen, Tabellen seit 0001; Beitritt per Einladungscode =
  // Crew-UUID — bewusst kein Kontakte-Import, wie bei Beer With Me).
  // --------------------------------------------------------------------------

  /// Eigene Crews (RLS zeigt nur Crews, in denen man Mitglied ist).
  Future<List<RemoteCrew>> myCrews() async {
    if (currentUser == null) return const [];
    try {
      final rows = await _client
          .from('crews')
          .select('id, name, emoji, owner_id, crew_members(count)')
          .order('created_at', ascending: true);
      return [
        for (final r in rows)
          RemoteCrew(
            id: r['id'] as String,
            name: r['name'] as String,
            emoji: (r['emoji'] as String?) ?? '👥',
            ownerId: r['owner_id'] as String,
            memberCount: _embeddedCount(r['crew_members']),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// PostgREST-`count`-Embed → int (Form: `[{"count": n}]`).
  static int _embeddedCount(Object? embed) {
    if (embed is List && embed.isNotEmpty && embed.first is Map) {
      return ((embed.first as Map)['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// Crew gründen. Rückgabe: (crewId, Fehlermeldung).
  Future<(String?, String?)> createCrew(String name, String emoji) async {
    final me = currentUser;
    if (me == null) return (null, 'Nicht angemeldet.');
    try {
      final row = await _client
          .from('crews')
          .insert({'name': name.trim(), 'emoji': emoji, 'owner_id': me.id})
          .select('id')
          .single();
      final id = row['id'] as String;
      await _client.from('crew_members').insert({
        'crew_id': id,
        'profile_id': me.id,
        'role': 'owner',
      });
      return (id, null);
    } on PostgrestException {
      return (null, 'Crew konnte nicht angelegt werden.');
    } catch (_) {
      return (null, 'Keine Verbindung.');
    }
  }

  /// Crew per Einladungscode (= Crew-UUID) beitreten.
  Future<String?> joinCrew(String code) async {
    final me = currentUser;
    if (me == null) return 'Nicht angemeldet.';
    if (!_uuidPattern.hasMatch(code.trim())) {
      return 'Das sieht nicht wie ein Einladungscode aus.';
    }
    try {
      await _client.from('crew_members').insert({
        'crew_id': code.trim(),
        'profile_id': me.id,
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'Du bist schon Mitglied dieser Crew.';
      if (e.code == '23503') return 'Diesen Einladungscode gibt es nicht.';
      return 'Beitritt fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung.';
    }
  }

  /// Crew verlassen (eigene Mitgliedschaft löschen).
  Future<String?> leaveCrew(String crewId) async {
    final me = currentUser;
    if (me == null) return 'Nicht angemeldet.';
    try {
      await _client
          .from('crew_members')
          .delete()
          .eq('crew_id', crewId)
          .eq('profile_id', me.id);
      return null;
    } catch (_) {
      return 'Keine Verbindung.';
    }
  }

  /// Crew auflösen (nur Besitzer, RLS erzwingt das).
  Future<String?> deleteCrew(String crewId) async {
    if (currentUser == null) return 'Nicht angemeldet.';
    try {
      await _client.from('crews').delete().eq('id', crewId);
      return null;
    } catch (_) {
      return 'Keine Verbindung.';
    }
  }

  /// Mitglieder einer Crew (Profil + Rolle).
  Future<List<({RemoteProfile profile, String role})>?> crewMembers(
      String crewId) async {
    if (currentUser == null) return null;
    try {
      final rows = await _client
          .from('crew_members')
          .select('role, '
              'profile:profiles!crew_members_profile_id_fkey($_profileCols)')
          .eq('crew_id', crewId)
          .order('created_at', ascending: true);
      return [
        for (final r in rows)
          (
            profile:
                RemoteProfile.fromRow(r['profile'] as Map<String, dynamic>),
            role: (r['role'] as String?) ?? 'member',
          ),
      ];
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // Sessions (Live-Beacon)
  // --------------------------------------------------------------------------

  /// Eigene Session online spiegeln (Fehler still: lokal gilt weiter).
  /// [crewId] gehört zu `visibility == crew` (RLS zeigt die Session dann
  /// nur den Crew-Mitgliedern).
  Future<void> upsertSession(local.Session session, {String? crewId}) async {
    final me = currentUser;
    if (me == null) return;
    final isCrew =
        session.visibility == local.SessionVisibility.crew && crewId != null;
    try {
      await _client.from('sessions').upsert({
        'id': session.id,
        'host_id': me.id,
        'venue_id': session.venueId,
        'venue_name': session.venueName,
        'message': session.message,
        'visibility': isCrew ? 'crew' : 'friends',
        'crew_id': isCrew ? crewId : null,
        'status': session.status.name,
        'started_at': session.startedAt.toUtc().toIso8601String(),
        'expires_at': session.expiresAt.toUtc().toIso8601String(),
        'ended_at': session.endedAt?.toUtc().toIso8601String(),
        'latitude': session.latitude,
        'longitude': session.longitude,
      });
    } catch (_) {}
  }

  /// Neues Ende einer laufenden Session übertragen (Verlängern).
  /// Die Grenzen prüft zusätzlich die `check`-Bedingung aus 0021.
  Future<void> updateSessionExpiry(String sessionId, DateTime until) async {
    try {
      await _client.from('sessions').update({
        'expires_at': until.toUtc().toIso8601String(),
      }).eq('id', sessionId);
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

  /// Check-in-Foto in den öffentlichen beer-photos-Bucket laden.
  /// Rückgabe: öffentliche URL, null bei Fehler/offline/abgemeldet.
  Future<String?> uploadCheckinPhoto(Uint8List bytes) async {
    final me = currentUser;
    if (me == null) return null;
    try {
      final path =
          '${me.id}/checkin-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('beer-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      return _client.storage.from('beer-photos').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// Eigenen Check-in serverseitig löschen.
  ///
  /// Toasts und Kommentare hängen mit `on delete cascade` daran und
  /// verschwinden mit; die RLS-Policy lässt nur eigene Zeilen zu.
  /// Rückgabe: null bei Erfolg, sonst die Fehlermeldung.
  Future<String?> deleteCheckinRemote(String checkinId) async {
    final me = currentUser;
    if (me == null) return 'Nicht angemeldet.';
    try {
      await _client
          .from('checkins')
          .delete()
          .eq('id', checkinId)
          .eq('profile_id', me.id);
      return null;
    } on PostgrestException catch (_) {
      // Zeile längst weg oder fremd: nichts zu tun, aber kein
      // Verbindungsfehler – die Warteschlange verwirft den Eintrag.
      return 'Löschen fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung – wird später übertragen.';
    }
  }

  /// Check-in-Foto aus dem Bucket entfernen. Best effort — ein verwaistes
  /// Bild ist harmlos, ein fehlgeschlagener Aufruf darf nichts blockieren.
  Future<void> deleteCheckinPhoto(String photoUrl) async {
    final me = currentUser;
    if (me == null) return;
    // Öffentliche URL → Objektpfad (…/beer-photos/<profil>/<datei>).
    const marker = '/beer-photos/';
    final index = photoUrl.indexOf(marker);
    if (index < 0) return;
    final path = photoUrl.substring(index + marker.length).split('?').first;
    // Nur eigene Objekte anfassen, auch wenn die Storage-Policy es ohnehin
    // erzwingt.
    if (!path.startsWith('${me.id}/')) return;
    try {
      await _client.storage.from('beer-photos').remove([path]);
    } catch (_) {}
  }

  /// Eigenen Check-in online spiegeln (denormalisiert, gleiche Zeile wie
  /// der Upload-Assistent).
  Future<void> insertCheckin(local.CheckinDetails details) async {
    final me = currentUser;
    if (me == null) return;
    final row = uploadRow(details, me.id);
    if (row == null) return;
    try {
      await _client.from('checkins').upsert(row);
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
      'opening_hours, opening_hours_json, price_half_l, price_third_l, '
      'verified, created_by, updated_at';

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

    /// Dekodierte JSON-Liste `[{"d":…,"von":…,"bis":…}]` oder null.
    Object? openingHoursJson,
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
            'opening_hours_json': openingHoursJson,
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
      // `local-…`-Pseudo-IDs (Offline-Gasthaus-Queue) nie hochschicken —
      // der Server kennt sie nicht (FK); der Name reicht bis zum Replay.
      'venue_id':
          (c.venueId?.startsWith('local-') ?? false) ? null : c.venueId,
      'beer_name': details.beer.name,
      'brewery_name': details.brewery.name,
      'beer_style': details.beer.style,
      'is_alcohol_free': details.beer.isAlcoholFree,
      'rating': c.rating,
      'note': c.note,
      'flavor_tags': [
        for (final t in c.flavorTags.split(','))
          if (t.trim().isNotEmpty) t.trim(),
      ],
      'serving_style': c.servingStyle?.name,
      'photo_url': c.photoUrl,
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

  // --------------------------------------------------------------------------
  // Cloud-Restore (Migration 0016): eigene Check-ins, Erfolge und
  // Wunschliste vom Server zurückholen — z. B. nach Neuinstallation oder
  // Gerätewechsel. null = offline/abgemeldet (Aufrufer versucht es später).
  // --------------------------------------------------------------------------

  /// Alle eigenen Check-ins mit vollen Spalten (Denorm-Daten reichen, um
  /// sie lokal zu rekonstruieren).
  Future<List<Map<String, dynamic>>?> myRemoteCheckins() async {
    final me = currentUser;
    if (me == null) return null;
    try {
      final rows = await _client
          .from('checkins')
          .select('id, rating, note, flavor_tags, serving_style, beer_name, '
              'beer_style, brewery_name, is_alcohol_free, venue_id, '
              'venue_name, photo_url, created_at')
          .eq('profile_id', me.id)
          .order('created_at', ascending: true);
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Eigene Erfolge: badge_slug → awarded_at.
  Future<Map<String, DateTime>?> myRemoteBadges() async {
    final me = currentUser;
    if (me == null) return null;
    try {
      final rows = await _client
          .from('user_badges')
          .select('badge_slug, awarded_at')
          .eq('profile_id', me.id);
      return {
        for (final r in rows)
          r['badge_slug'] as String:
              DateTime.parse(r['awarded_at'] as String).toUtc(),
      };
    } catch (_) {
      return null;
    }
  }

  /// Erfolge hochspiegeln (idempotent; bestehende Zeilen bleiben stehen).
  Future<bool> uploadBadges(Map<String, DateTime> badges) async {
    final me = currentUser;
    if (me == null || badges.isEmpty) return badges.isEmpty;
    try {
      await _client.from('user_badges').upsert([
        for (final e in badges.entries)
          {
            'profile_id': me.id,
            'badge_slug': e.key,
            'awarded_at': e.value.toUtc().toIso8601String(),
          },
      ], ignoreDuplicates: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Eigene Wunschliste: beer_key (lokale Bier-ID) → created_at.
  Future<Map<String, DateTime>?> myRemoteWishlist() async {
    final me = currentUser;
    if (me == null) return null;
    try {
      final rows = await _client
          .from('wishlist_items')
          .select('beer_key, created_at')
          .eq('profile_id', me.id);
      return {
        for (final r in rows)
          r['beer_key'] as String:
              DateTime.parse(r['created_at'] as String).toUtc(),
      };
    } catch (_) {
      return null;
    }
  }

  /// Wunschlisten-Eintrag serverseitig setzen/entfernen (best effort).
  Future<void> setWishlistRemote(String beerKey, {required bool add}) async {
    final me = currentUser;
    if (me == null) return;
    try {
      if (add) {
        await _client.from('wishlist_items').upsert({
          'profile_id': me.id,
          'beer_key': beerKey,
        }, ignoreDuplicates: true);
      } else {
        await _client
            .from('wishlist_items')
            .delete()
            .eq('profile_id', me.id)
            .eq('beer_key', beerKey);
      }
    } catch (_) {}
  }

  Future<List<RemoteCheckin>> friendCheckins({int limit = 50}) async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await _client
          .from('checkins')
          .select('id, beer_name, brewery_name, beer_style, is_alcohol_free, '
              'rating, note, venue_name, session_id, photo_url, created_at, '
              'author:profiles!checkins_profile_id_fkey($_profileCols)')
          .neq('profile_id', me.id)
          .order('created_at', ascending: false)
          .limit(limit);
      return [for (final r in rows) _checkinFromRow(r)];
    } catch (_) {
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // Toasts & Kommentare (Server = Wahrheit für alle hochgeladenen
  // Check-ins; RLS aus 0001 begrenzt auf sichtbare Check-ins).
  // --------------------------------------------------------------------------

  /// Toast-/Kommentar-Stand für eine Menge von Check-in-UUIDs.
  /// null = offline/abgemeldet.
  Future<Map<String, ({int toasts, bool toastedByMe, int comments})>?>
      reactionsFor(List<String> checkinIds) async {
    final me = currentUser;
    if (me == null) return null;
    if (checkinIds.isEmpty) return const {};
    try {
      final toastRows = await _client
          .from('toasts')
          .select('checkin_id, profile_id')
          .inFilter('checkin_id', checkinIds);
      final commentRows = await _client
          .from('comments')
          .select('checkin_id')
          .inFilter('checkin_id', checkinIds);
      final toastCount = <String, int>{};
      final mine = <String>{};
      for (final r in toastRows) {
        final id = r['checkin_id'] as String;
        toastCount[id] = (toastCount[id] ?? 0) + 1;
        if (r['profile_id'] == me.id) mine.add(id);
      }
      final commentCount = <String, int>{};
      for (final r in commentRows) {
        final id = r['checkin_id'] as String;
        commentCount[id] = (commentCount[id] ?? 0) + 1;
      }
      return {
        for (final id in checkinIds)
          id: (
            toasts: toastCount[id] ?? 0,
            toastedByMe: mine.contains(id),
            comments: commentCount[id] ?? 0,
          ),
      };
    } catch (_) {
      return null;
    }
  }

  /// Eigenen Toast setzen/entfernen (idempotent). true = übernommen.
  Future<bool> setToastRemote(String checkinId, {required bool on}) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      if (on) {
        await _client.from('toasts').upsert({
          'checkin_id': checkinId,
          'profile_id': me.id,
        }, ignoreDuplicates: true);
      } else {
        await _client
            .from('toasts')
            .delete()
            .eq('checkin_id', checkinId)
            .eq('profile_id', me.id);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kommentare eines Check-ins, älteste zuerst. null = offline.
  Future<List<({RemoteProfile author, String body, DateTime createdAt})>?>
      commentsRemote(String checkinId) async {
    if (currentUser == null) return null;
    try {
      final rows = await _client
          .from('comments')
          .select('body, created_at, '
              'author:profiles!comments_profile_id_fkey($_profileCols)')
          .eq('checkin_id', checkinId)
          .order('created_at', ascending: true);
      return [
        for (final r in rows)
          (
            author:
                RemoteProfile.fromRow(r['author'] as Map<String, dynamic>),
            body: r['body'] as String,
            createdAt:
                DateTime.parse(r['created_at'] as String).toLocal(),
          ),
      ];
    } catch (_) {
      return null;
    }
  }

  /// Kommentar schreiben. null = ok, sonst Fehlermeldung.
  Future<String?> addCommentRemote(String checkinId, String body) async {
    final me = currentUser;
    if (me == null) return 'Nicht angemeldet.';
    try {
      await _client.from('comments').insert({
        'checkin_id': checkinId,
        'profile_id': me.id,
        'body': body.trim(),
      });
      return null;
    } on PostgrestException {
      return 'Kommentar konnte nicht gespeichert werden.';
    } catch (_) {
      return 'Keine Verbindung.';
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
        photoUrl: r['photo_url'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );
}
