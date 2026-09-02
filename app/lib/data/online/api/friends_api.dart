/// Freunde, Anfragen, Suche, Kreise, Blockieren und Melden.
///
/// Teil der Aufteilung von `online_service.dart` (Backlog B-3). Der
/// Einstieg bleibt `OnlineService`; diese Klasse hängt dort als Feld
/// `friends`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'online_api.dart';

class FriendsApi extends OnlineApi {
  const FriendsApi(super.client, super.nutzer);

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
      final rows = await client
          .from('profiles')
          .select(OnlineApi.profileCols)
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
      final row = await client
          .from('profiles')
          .select(OnlineApi.profileCols)
          .eq('id', profileId)
          .maybeSingle();
      return row == null ? null : RemoteProfile.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  /// Eigene Einstufung eines Freundes setzen. Einseitig und privat —
  /// der andere erfährt nichts davon.
  ///
  /// Gibt zurück, ob der Server die Änderung angenommen hat. Der Kreis
  /// steuert, wer den eigenen Beacon sieht — eine Erfolgsmeldung nach
  /// einem fehlgeschlagenen Aufruf würde also über die eigene
  /// Sichtbarkeit täuschen. Genau dort darf die App nicht schummeln.
  Future<bool> setFriendTier(String profileId, FriendTier tier) async {
    if (currentUser == null) return false;
    try {
      await client.rpc('set_friend_tier',
          params: {'p_other': profileId, 'p_tier': tier.name_});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Eigene Bierlaune. Seit 0024 über eine Funktion statt über die
  /// Spalte — das Spaltenrecht ist entzogen, damit die Abstufung nicht
  /// an der App hängt.
  Future<DateTime?> myThirstyUntil() async {
    if (currentUser == null) return null;
    try {
      final value = await client.rpc('my_thirsty_until');
      if (value == null) return null;
      return DateTime.parse(value as String).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Freunde mit aktiver Bierlaune — serverseitig auf Kreis „Freund"
  /// und höher gefiltert.
  Future<List<RemoteProfile>> thirstyFriends() async {
    if (currentUser == null) return const [];
    try {
      final rows = await client.rpc('thirsty_friends');
      return [
        for (final r in (rows as List).cast<Map<String, dynamic>>())
          RemoteProfile.fromRow(r),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<String?> sendFriendRequest(String profileId) async {
    try {
      await client.from('friendships').insert({
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
      final rows = await client
          .from('friendships')
          .select('id, requester:profiles!friendships_requester_id_fkey(${OnlineApi.profileCols})')
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
    } catch (e) {
      // Nicht stumm: Genau hier lag vom 2026-08-15 bis 2026-09-02 ein
      // 400 vom Server (kaputte Spaltenliste), und die App zeigte einfach
      // „keine Anfragen". Ein Fehler, den man nicht sieht, ist keiner.
      debugPrint('incomingRequests: $e');
      return const [];
    }
  }

  /// Anfragen, die ich selbst gestellt habe und die noch offen sind.
  Future<List<OutgoingRequest>> outgoingRequests() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('friendships')
          .select('id, addressee:profiles!friendships_addressee_id_fkey('
              '${OnlineApi.profileCols})')
          .eq('requester_id', me.id)
          .eq('status', 'pending');
      return [
        for (final r in rows)
          OutgoingRequest(
            friendshipId: r['id'] as String,
            to: RemoteProfile.fromRow(r['addressee'] as Map<String, dynamic>),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Eine eigene Anfrage zurueckziehen.
  ///
  /// Ohne diesen Weg war ein versehentlicher Scan endgueltig: Man konnte
  /// eine gestellte Anfrage weder sehen noch zuruecknehmen und musste
  /// darauf hoffen, dass der andere sie ablehnt.
  ///
  /// Die Zeile wird geloescht statt auf einen Status gesetzt — dann ist
  /// derselbe Mensch spaeter wieder anfragbar. Der Unique-Index auf dem
  /// Paar liesse das sonst nicht zu.
  Future<bool> withdrawRequest(String friendshipId) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      // `requester_id`-Bedingung nicht nur der Sauberkeit halber: Ohne sie
      // wuerde derselbe Aufruf eine **eingehende** Anfrage loeschen, statt
      // sie abzulehnen — dieselbe Zeile, anderer Vorgang.
      final betroffen = await client
          .from('friendships')
          .delete()
          .eq('id', friendshipId)
          .eq('requester_id', me.id)
          .eq('status', 'pending')
          .select('id');
      return betroffen.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Freundschaftsanfrage annehmen oder ablehnen.
  ///
  /// Gibt zurück, ob der Server es übernommen hat. Eine stille
  /// Erfolgsmeldung wäre hier besonders irreführend: Wer glaubt,
  /// abgelehnt zu haben, rechnet nicht mehr damit, gesehen zu werden.
  Future<bool> respondRequest(String friendshipId,
      {required bool accept}) async {
    try {
      if (accept) {
        await client
            .from('friendships')
            .update({'status': 'accepted'}).eq('id', friendshipId);
      } else {
        await client.from('friendships').delete().eq('id', friendshipId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 🍺 Bierlaune setzen (bis [until]) oder beenden (null).
  /// Gibt zurück, ob der Server es übernommen hat — die Bierlaune ist
  /// nur dann etwas wert, wenn Freunde sie sehen.
  Future<bool> setBierlaune(DateTime? until) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      await client.from('profiles').update({
        'thirsty_until': until?.toUtc().toIso8601String(),
      }).eq('id', me.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<RemoteProfile>> friends() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('friendships')
          .select('requester_id, requester_tier, addressee_tier, '
              'requester:profiles!friendships_requester_id_fkey(${OnlineApi.profileCols}), '
              'addressee:profiles!friendships_addressee_id_fkey(${OnlineApi.profileCols})')
          .eq('status', 'accepted')
          .or('requester_id.eq.${me.id},addressee_id.eq.${me.id}');
      return [
        for (final r in rows)
          RemoteProfile.fromRow(
            (r['requester'] as Map<String, dynamic>)['id'] == me.id
                ? r['addressee'] as Map<String, dynamic>
                : r['requester'] as Map<String, dynamic>,
            // Mein Kreis für den anderen steht in „meiner" Spalte.
            tier: friendTierFromName(r['requester_id'] == me.id
                ? r['requester_tier'] as String?
                : r['addressee_tier'] as String?),
          ),
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
      await client.from('blocks').insert({
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
      await client.from('friendships').delete().or(
          'and(requester_id.eq.${me.id},addressee_id.eq.$profileId),'
          'and(requester_id.eq.$profileId,addressee_id.eq.${me.id})');
    } catch (_) {}
    return null;
  }

  /// Gibt zurück, ob der Server es übernommen hat. Blockieren und
  /// Entsperren sind Sicherheitsentscheidungen — über deren Ausgang darf
  /// die App nicht schweigen.
  Future<bool> unblockProfile(String profileId) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      await client
          .from('blocks')
          .delete()
          .eq('blocker_id', me.id)
          .eq('blocked_id', profileId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Eigene Blockliste (nur der Blockierende sieht sie – RLS).
  Future<List<RemoteProfile>> blockedProfiles() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('blocks')
          .select('blocked:profiles!blocks_blocked_id_fkey(${OnlineApi.profileCols})')
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
      await client.from('reports').insert({
        'reporter_id': me.id,
        'reported_id': profileId,
        'reason': trimmed,
      });
      return null;
    } catch (_) {
      return 'Melden fehlgeschlagen.';
    }
  }
}
