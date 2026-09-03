import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';

import 'api/checkins_api.dart';
import 'api/devices_api.dart';
import 'api/feedback_api.dart';
import 'api/online_api.dart';
import 'api/crews_api.dart';
import 'api/friends_api.dart';
import 'api/moderation_api.dart';
import 'api/notifications_api.dart';
import 'api/sessions_api.dart';
import 'api/venues_api.dart';
import 'models.dart';

export 'api/checkins_api.dart';
export 'api/devices_api.dart';
export 'api/feedback_api.dart';
export 'api/notifications_api.dart';
export 'api/online_api.dart';
export 'api/crews_api.dart';
export 'api/friends_api.dart';
export 'api/moderation_api.dart';
export 'api/sessions_api.dart';
export 'api/venues_api.dart';

// Die Antwort-Typen stehen in models.dart. Weitergereicht, damit die
// bestehenden Importeure von `online_service.dart` unverändert bleiben.
export 'models.dart';

class OnlineService {
  OnlineService(this._client)
      : friends = FriendsApi(_client, () => _client.auth.currentUser),
        sessions = SessionsApi(_client, () => _client.auth.currentUser),
        checkins = CheckinsApi(_client, () => _client.auth.currentUser),
        venues = VenuesApi(_client, () => _client.auth.currentUser),
        notifications =
            NotificationsApi(_client, () => _client.auth.currentUser),
        devices = DevicesApi(_client, () => _client.auth.currentUser),
        feedback = FeedbackApi(_client, () => _client.auth.currentUser),
        moderation =
            ModerationApi(_client, () => _client.auth.currentUser),
        crews = CrewsApi(_client, () => _client.auth.currentUser);

  final SupabaseClient _client;

  /// Der Supabase-Client.
  ///
  /// Öffentlich, damit ein Test-Doppel für die Unterbereiche **dieselbe**
  /// Instanz weiterreichen kann. Ein zweiter Client startet einen zweiten
  /// Auth-Timer, und ein Widget-Test kommt dann nie zur Ruhe.
  SupabaseClient get client => _client;

  /// Freunde, Anfragen, Suche, Kreise, Blockieren und Melden.
  final FriendsApi friends;

  /// Die Glocke: Benachrichtigungen lesen, live und als Bestand.
  final NotificationsApi notifications;

  /// Geraetetoken fuer Push (Tabelle `devices`).
  final DevicesApi devices;

  /// Fehler melden, Wuensche, Roadmap (Testphase).
  final FeedbackApi feedback;

  /// Gemeldete Profile ansehen und abschliessen (Moderatoren, Admins).
  final ModerationApi moderation;

  /// Crew-Feed und Beitritt per sprechbarem Code.
  final CrewsApi crews;

  /// Live-Beacons: starten, spiegeln, verlängern, beenden.
  final SessionsApi sessions;

  /// Check-ins, Fotos, Wiederherstellung, Toasts und Kommentare.
  final CheckinsApi checkins;

  /// Gasthäuser der gemeinsamen Datenbank.
  final VenuesApi venues;

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

  /// Anzeigename und Avatar am Server aendern (nur eigene Zeile, RLS).
  Future<bool> updateMyProfile({String? displayName, String? avatarEmoji}) async {
    final me = currentUser;
    if (me == null) return false;
    final patch = <String, dynamic>{
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
      if (avatarEmoji != null && avatarEmoji.isNotEmpty)
        'avatar_emoji': avatarEmoji,
    };
    if (patch.isEmpty) return true;
    try {
      await _client.from('profiles').update(patch).eq('id', me.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// „Passwort vergessen": Supabase schickt einen Link an die Adresse.
  ///
  /// Gab es bis 2026-09-02 nicht. Mit dem Beta-Gate hiess ein vergessenes
  /// Passwort: ausgesperrt, neues Konto, alle Freundschaften weg.
  Future<String?> resetPassword(String email) async {
    final adresse = email.trim();
    if (adresse.isEmpty || !adresse.contains('@')) {
      return 'Bitte zuerst deine E-Mail-Adresse eintragen.';
    }
    try {
      await _client.auth.resetPasswordForEmail(adresse,
          redirectTo: kIsWeb ? Uri.base.origin + Uri.base.path : oauthRedirect);
      return null;
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (_) {
      return 'Keine Verbindung – bitte später erneut versuchen.';
    }
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
  // Crews (Gruppen, Tabellen seit 0001; Beitritt per Einladungscode =
  // Crew-UUID — bewusst kein Kontakte-Import, wie bei Beer With Me).
  // --------------------------------------------------------------------------

  /// Eigene Crews (RLS zeigt nur Crews, in denen man Mitglied ist).
  Future<List<RemoteCrew>> myCrews() async {
    if (currentUser == null) return const [];
    try {
      final rows = await _client
          .from('crews')
          .select('id, name, emoji, owner_id, join_code, crew_members(count)')
          .order('created_at', ascending: true);
      return [
        for (final r in rows)
          RemoteCrew(
            id: r['id'] as String,
            name: r['name'] as String,
            emoji: (r['emoji'] as String?) ?? '👥',
            ownerId: r['owner_id'] as String,
            memberCount: _embeddedCount(r['crew_members']),
            joinCode: r['join_code'] as String?,
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
    if (!OnlineApi.uuidPattern.hasMatch(code.trim())) {
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
  // Community-Bierdatenbank (Migration 0010): Nutzer tragen neue Biere mit
  // Foto + EAN direkt ein; die Community validiert über Check-ins („geloggt")
  // und „Kein Bier"-Meldungen.
  // --------------------------------------------------------------------------

  /// Biere anderer Nutzer nach Namen suchen — für die Live-Vorschläge.
  ///
  /// Die lokale Datenbank kennt die gebündelten Biere und die eigenen.
  /// Was ein anderer Nutzer gerade erst angelegt hat, steht nur hier.
  /// Deshalb die Reihenfolge in der Oberfläche: erst lokal (sofort), dann
  /// dieser Nachschlag.
  ///
  /// Leere Liste bei Fehler oder ohne Anmeldung — Vorschläge sind ein
  /// Zusatz, kein Bestandteil des Eintragens. Wer offline ein Bier anlegt,
  /// soll davon nichts merken.
  Future<List<RemoteBeer>> searchCommunityBeers(String query) async {
    final begriff = query.trim();
    if (currentUser == null || begriff.length < 2) return const [];
    // % und _ sind LIKE-Platzhalter, Komma und Klammern gehören zur
    // PostgREST-Filtersyntax. Beides würde die Suche weiter machen, als
    // der Mensch sie gemeint hat.
    final sicher = begriff.replaceAll(RegExp('[%_,()\\\\]'), '');
    if (sicher.length < 2) return const [];
    try {
      final rows = await _client
          .from('beers')
          .select('name, style, abv, is_alcohol_free, description, '
              'label_url, brewery:breweries(name, country, city)')
          .ilike('name', '%$sicher%')
          .limit(10);
      return [
        for (final row in rows)
          RemoteBeer(
            name: row['name'] as String,
            style: (row['style'] as String?) ?? 'Bier',
            breweryName:
                (row['brewery'] as Map<String, dynamic>?)?['name'] as String?,
            breweryCountry: (row['brewery'] as Map<String, dynamic>?)?['country']
                as String?,
            breweryCity:
                (row['brewery'] as Map<String, dynamic>?)?['city'] as String?,
            abv: (row['abv'] as num?)?.toDouble(),
            isAlcoholFree: (row['is_alcohol_free'] as bool?) ?? false,
            description: row['description'] as String?,
            labelUrl: row['label_url'] as String?,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Bier per Barcode in der Community-DB suchen (nur angemeldet, RLS).
  Future<RemoteBeer?> communityBeerByBarcode(String ean) async {
    if (currentUser == null) return null;
    try {
      // Zuerst in `beer_barcodes` (0028): Dort stehen **alle** Codes eines
      // Bieres. `beers.barcode` haelt nur einen einzigen — die Spalte ist
      // `unique`, und genau daran scheiterte bisher jeder nachgetragene
      // Code. Er wurde gespeichert und beim Suchen nie gelesen.
      final zuordnung = await _client
          .from('beer_barcodes')
          .select('beer_id')
          .eq('ean', ean)
          .maybeSingle();

      // Seit 0030 steht jeder Code in `beer_barcodes` (Backfill inklusive).
      // `beers.barcode` wird nicht mehr angefasst — die Spalte faellt mit
      // 0032, sobald kein Client sie mehr liest.
      if (zuordnung == null) return null;
      final row = await _client
          .from('beers')
          .select('name, style, abv, is_alcohol_free, description, '
              'label_url, brewery:breweries(name, country, city)')
          .eq('id', zuordnung['beer_id'] as String)
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
        barcode: ean,
      );
    } catch (_) {
      return null;
    }
  }

  /// Neues Bier direkt in die Community-DB eintragen (unverifiziert; die
  /// Brauerei wird per Name wiederverwendet oder mit angelegt, das Foto
  /// landet im öffentlichen beer-photos-Bucket).
  /// Kleinste noch unterstützte App-Version (Migration 0029).
  ///
  /// `null` heißt „nicht erreichbar oder nicht gesetzt" — und führt
  /// bewusst **nie** zur Sperre. Ein Netzproblem darf niemanden aus einer
  /// App aussperren, die ohne Netz vollständig funktioniert.
  ///
  /// Absichtlich ohne Anmeldung lesbar: Sonst umginge man den Riegel
  /// durch Abmelden.
  Future<String?> minSupportedVersion() async {
    try {
      final row = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'min_supported_version')
          .maybeSingle();
      return row?['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Barcode samt Gebindegröße für alle hinterlegen (Migration 0028).
  ///
  /// Eine EAN bezeichnet die Handelseinheit, nicht das Getränk — deshalb
  /// eine eigene Tabelle mit mehreren Zeilen je Bier statt der einzelnen
  /// Spalte `beers.barcode` aus 0010, in die der zweite Code eines Biers
  /// nie passte.
  ///
  /// Fehler bleiben still und das ist hier vertretbar: Lokal ist der Code
  /// bereits vermerkt, es geht nichts verloren, und beim nächsten Scan
  /// versucht es die App erneut. Der Rückgabewert steht trotzdem bereit.
  Future<bool> upsertBeerBarcode(
    String ean,
    String beerId, {
    int? volumeMl,
  }) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      await _client.from('beer_barcodes').upsert({
        'ean': ean,
        'beer_id': beerId,
        if (volumeMl != null) 'volume_ml': volumeMl,
        'created_by': me.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Was der Server über einen Barcode weiß: welches Bier, welche Größe.
  ///
  /// `null` heißt offline oder unbekannt — beides führt zum selben
  /// Verhalten, nämlich „selbst anlegen".
  Future<({String beerId, int? volumeMl})?> beerBarcode(String ean) async {
    if (currentUser == null) return null;
    try {
      final row = await _client
          .from('beer_barcodes')
          .select('beer_id, volume_ml')
          .eq('ean', ean)
          .maybeSingle();
      if (row == null) return null;
      return (
        beerId: row['beer_id'] as String,
        volumeMl: (row['volume_ml'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

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

      final neu = await _client.from('beers').insert({
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
        'created_by': me.id,
      }).select('id').single();

      // Der Code gehoert nach `beer_barcodes` — dort sucht der Scanner.
      // In `beers.barcode` wird seit 0.10.4 nichts mehr geschrieben.
      if (barcode != null && barcode.isNotEmpty) {
        await _client.from('beer_barcodes').upsert({
          'ean': barcode,
          'beer_id': neu['id'],
          'created_by': me.id,
        }, onConflict: 'ean');
      }
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
      // Dasselbe Problem wie beim Suchen: Ueber `beers.barcode` trifft
      // ein nachgetragener Code keine Zeile, und ein Update auf null
      // Zeilen wirft nichts — die App haette „gespeichert" gemeldet und
      // nichts geaendert.
      final zuordnung = await _client
          .from('beer_barcodes')
          .select('beer_id')
          .eq('ean', barcode)
          .maybeSingle();
      if (zuordnung == null) return 'Dieses Bier ist am Server unbekannt.';
      await _client
          .from('beers')
          .update(patch)
          .eq('id', zuordnung['beer_id'] as String);
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
  /// Serverseitige Bestätigung eines Abschlusses. Fehler bleiben still:
  /// Das Abzeichen ist lokal bereits vergeben, und die Wiederherstellung
  /// holt den Serverstand beim nächsten Anmelden nach.
  Future<bool> completeChallenge(String challengeId) async {
    if (currentUser == null) return false;
    try {
      await _client
          .rpc('complete_challenge', params: {'p_challenge': challengeId});
    } catch (_) {
      return false;
    }
    return true;
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

}
