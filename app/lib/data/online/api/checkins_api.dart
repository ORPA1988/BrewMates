/// Check-ins: hochladen, Fotos, Wiederherstellung, Toasts und Kommentare.
///
/// Teil der Aufteilung von `online_service.dart` (Backlog B-3). Der
/// Einstieg bleibt `OnlineService`; diese Klasse hängt dort als Feld
/// `checkins`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../db/database.dart' as local;
import '../models.dart';
import '../remote_mapping.dart';
import 'online_api.dart';

class CheckinsApi extends OnlineApi {
  const CheckinsApi(super.client, super.nutzer);

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
      await client.storage.from('beer-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      return client.storage.from('beer-photos').getPublicUrl(path);
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
      await client
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
  /// Aufräumen im Bucket. Fehler bleiben still und das ist vertretbar:
  /// Der Check-in ist gelöscht, zurück bleibt allenfalls eine verwaiste
  /// Datei — ärgerlich, aber niemand sieht sie, und kein Zustand hängt
  /// davon ab.
  Future<bool> deleteCheckinPhoto(String photoUrl) async {
    final me = currentUser;
    if (me == null) return false;
    // Öffentliche URL → Objektpfad (…/beer-photos/<profil>/<datei>).
    const marker = '/beer-photos/';
    final index = photoUrl.indexOf(marker);
    if (index < 0) return false;
    final path = photoUrl.substring(index + marker.length).split('?').first;
    // Nur eigene Objekte anfassen, auch wenn die Storage-Policy es ohnehin
    // erzwingt.
    if (!path.startsWith('${me.id}/')) return false;
    try {
      await client.storage.from('beer-photos').remove([path]);
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Eigenen Check-in online spiegeln (denormalisiert, gleiche Zeile wie
  /// der Upload-Assistent).
  /// Fehler bleiben still, weil es einen echten Nachreich-Pfad gibt:
  /// `checkinAutoSyncProvider` überträgt offen gebliebene Check-ins bei
  /// Anmeldung, nach jedem lokalen Check-in und alle fünf Minuten, und der
  /// Upsert über die Client-UUID macht das idempotent. Hier zu lärmen
  /// hieße, den Nutzer für etwas zu behelligen, das sich von selbst löst.
  Future<bool> insertCheckin(local.CheckinDetails details) async {
    final me = currentUser;
    if (me == null) return false;
    final row = uploadRow(details, me.id);
    if (row == null) return false;
    try {
      await client.from('checkins').upsert(row);
    } catch (_) {
      // Häufigster Grund für einen Fehlschlag mit Runde: Der Server kennt
      // sie nicht, weil ihr eigener Upload scheiterte. Der Fremdschlüssel
      // ließe dann den **ganzen** Check-in liegen — und der ist wichtiger
      // als seine Zuordnung. Also einmal ohne, statt gar nicht.
      if (row['session_id'] == null) return false;
      try {
        await client
            .from('checkins')
            .upsert({...row, 'session_id': null});
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  // --------------------------------------------------------------------------
  // Upload-Assistent (Roadmap Stufe B): lokale Alt-Check-ins einmalig und
  // nachvollziehbar ins Konto übertragen. Idempotent per Upsert über die
  // clientseitig erzeugten UUIDs – mehrfaches Ausführen schadet nie.
  // --------------------------------------------------------------------------


  /// Nur echte, in der App entstandene Check-ins sind übertragbar –
  /// Demo-/Seed-Einträge tragen keine UUID und bleiben lokal.
  static bool isUploadable(local.CheckinDetails details) =>
      OnlineApi.uuidPattern.hasMatch(details.checkin.id);

  /// Die Runde, wie der Server sie kennt — oder `null`.
  ///
  /// **Warum das lange gar nicht mitging.** `uploadRow` schickte
  /// `session_id: null`, hart verdrahtet. Damit kam die Zuordnung **nie**
  /// am Server an, auch die zur eigenen Runde nicht — und alles, was
  /// darauf aufbaut, lief ins Leere: die Crew-Bilanz fand nichts, und der
  /// Runden-Zweig in `checkins_select` (0050) griff nie, weil
  /// `session_id is not null` nie zutraf.
  ///
  /// Warum es trotzdem eine Prüfung braucht: Lokal stehen dort dreierlei
  /// IDs. Eigene Runden tragen dieselbe UUID wie am Server
  /// (`upsertSession` schickt `id` unverändert), fremde tragen sie mit
  /// `remote-`-Präfix, und Demo-/Seed-Einträge tragen sprechende Namen.
  /// Nur die ersten beiden existieren am Server; eine sprechende ID
  /// verletzt dort den Fremdschlüssel und ließe den ganzen Check-in
  /// scheitern.
  static String? serverSessionId(String? localId) {
    if (localId == null) return null;
    final blank = stripRemote(localId);
    return OnlineApi.uuidPattern.hasMatch(blank) ? blank : null;
  }

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
      'session_id': serverSessionId(c.sessionId),
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
      'volume_ml': c.volumeMl,
      'photo_url': c.photoUrl,
      'venue_name': c.venueName,
      // Bis 0.10.19 stand hier fest `'friends'` — die Spalte gab es am
      // Server seit 0001, die Wahl in der App nie (Funktion 44).
      'visibility': c.visibility.name,
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
          await client.from('checkins').select('id').eq('profile_id', me.id);
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
        await client
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

  /// Spaltenliste, mit der sich ein Check-in lokal rekonstruieren lässt.
  static const _restoreCols =
      'id, rating, note, flavor_tags, serving_style, volume_ml, '
      'beer_name, beer_style, brewery_name, is_alcohol_free, '
      'venue_id, venue_name, photo_url, created_at';

  /// Nur die genannten Check-ins holen — die Grundlage der inkrementellen
  /// Wiederherstellung (Backlog B-2).
  ///
  /// Die Wiederherstellung fragt zuerst über [myRemoteCheckinIds] ab, was
  /// der Server überhaupt hat (eine UUID je Zeile), vergleicht das lokal
  /// und lädt hier **nur die Lücke** nach. Beim Normalfall „nichts Neues"
  /// entfällt dieser Aufruf ganz.
  ///
  /// Bewusst kein Zeitstempel-Wasserzeichen: `created_at` stammt vom
  /// Client, und ein Check-in, der offline entstand und Tage später
  /// hochgeladen wird, liegt zeitlich VOR dem Wasserzeichen. Er würde nie
  /// wiederhergestellt. Der ID-Abgleich kennt dieses Problem nicht.
  Future<List<Map<String, dynamic>>?> checkinsByIds(List<String> ids) async {
    if (currentUser == null) return null;
    if (ids.isEmpty) return const [];
    final alle = <Map<String, dynamic>>[];
    try {
      // In Blöcken, sonst sprengt die Liste die URL-Länge.
      for (var i = 0; i < ids.length; i += 50) {
        final block = ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50);
        final rows = await client
            .from('checkins')
            .select(_restoreCols)
            .inFilter('id', block)
            .order('created_at', ascending: true);
        alle.addAll(rows.cast<Map<String, dynamic>>());
      }
      return alle;
    } catch (_) {
      return null;
    }
  }

  /// Alle eigenen Check-ins mit vollen Spalten (Denorm-Daten reichen, um
  /// sie lokal zu rekonstruieren).
  Future<List<Map<String, dynamic>>?> myRemoteCheckins() async {
    final me = currentUser;
    if (me == null) return null;
    try {
      final rows = await client
          .from('checkins')
          .select(_restoreCols)
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
      final rows = await client
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
      await client.from('user_badges').upsert([
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
      final rows = await client
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
  /// Spiegelung der Wunschliste. Fehler bleiben still: Lokal ist die
  /// Wahrheit, und `cloudRestoreProvider` gleicht beide Seiten per
  /// Vereinigung wieder an — es kann nichts verloren gehen.
  Future<bool> setWishlistRemote(String beerKey, {required bool add}) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      if (add) {
        await client.from('wishlist_items').upsert({
          'profile_id': me.id,
          'beer_key': beerKey,
        }, ignoreDuplicates: true);
      } else {
        await client
            .from('wishlist_items')
            .delete()
            .eq('profile_id', me.id)
            .eq('beer_key', beerKey);
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  Future<List<RemoteCheckin>> friendCheckins({int limit = 50}) async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('checkins')
          .select('id, beer_name, brewery_name, beer_style, is_alcohol_free, '
              'rating, note, venue_name, session_id, photo_url, created_at, '
              'author:profiles!checkins_profile_id_fkey(${OnlineApi.profileCols})')
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
      final toastRows = await client
          .from('toasts')
          .select('checkin_id, profile_id')
          .inFilter('checkin_id', checkinIds);
      final commentRows = await client
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
        await client.from('toasts').upsert({
          'checkin_id': checkinId,
          'profile_id': me.id,
        }, ignoreDuplicates: true);
      } else {
        await client
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
      final rows = await client
          .from('comments')
          .select('body, created_at, '
              'author:profiles!comments_profile_id_fkey(${OnlineApi.profileCols})')
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
      await client.from('comments').insert({
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

  // Die Zuordnung liegt seit dem Crew-Feed in `RemoteCheckin.fromRow` —
  // zwei Kopien laufen auseinander, sobald eine Spalte dazukommt.
  RemoteCheckin _checkinFromRow(Map<String, dynamic> r) =>
      RemoteCheckin.fromRow(r);
}
