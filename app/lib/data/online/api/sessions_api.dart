/// Live-Beacons: starten, spiegeln, verlaengern, beenden.
///
/// Teil der Aufteilung von `online_service.dart` (Backlog B-3). Der
/// Einstieg bleibt `OnlineService`; diese Klasse hängt dort als Feld
/// `sessions`.
library;

import 'dart:async';


import '../../db/database.dart' as local;
import '../models.dart';
import 'online_api.dart';

class SessionsApi extends OnlineApi {
  const SessionsApi(super.client, super.nutzer);

  // --------------------------------------------------------------------------
  // Sessions (Live-Beacon)
  // --------------------------------------------------------------------------

  /// Eigene Session online spiegeln (Fehler still: lokal gilt weiter).
  /// [crewId] gehört zu `visibility == crew` (RLS zeigt die Session dann
  /// nur den Crew-Mitgliedern).
  /// Fehler bleiben still: Lokal gilt die Session weiter, und
  /// [endStaleSessions] räumt einen Beacon auf, der es nie zum Server
  /// geschafft hat. Rückgabe sagt trotzdem, ob es ankam.
  Future<bool> upsertSession(local.Session session, {String? crewId}) async {
    final me = currentUser;
    if (me == null) return false;
    final isCrew =
        session.visibility == local.SessionVisibility.crew && crewId != null;
    try {
      await client.from('sessions').upsert({
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
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Neues Ende einer laufenden Session übertragen (Verlängern).
  /// Die Grenzen prüft zusätzlich die `check`-Bedingung aus 0021.
  /// Neues Ende einer laufenden Session melden.
  ///
  /// Gibt zurück, ob es angekommen ist. Bewusst **keine** Warteschlange
  /// nach dem Muster `venue_edit_queue`: Eine Verlängerung ist an den
  /// Moment gebunden. Später nachgereicht würde sie eine längst beendete
  /// Session wiederbeleben und den Aufenthaltsort erneut sichtbar machen
  /// — das Gegenteil dessen, was die Laufzeitgrenze aus 0021 soll. Also
  /// sofort melden oder ehrlich scheitern.
  Future<bool> updateSessionExpiry(String sessionId, DateTime until) async {
    try {
      await client.from('sessions').update({
        'expires_at': until.toUtc().toIso8601String(),
      }).eq('id', sessionId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Beacon serverseitig beenden.
  ///
  /// Gibt zurück, ob es angekommen ist. Schlägt es fehl, zeigt der Server
  /// Freunden weiter den Aufenthaltsort — bis `end_expired_sessions()`
  /// per Cron greift, und das kann Stunden dauern. Deshalb räumt
  /// [endStaleSessions] beim nächsten Abgleich nach.
  Future<bool> endSession(String sessionId) async {
    try {
      await client.from('sessions').update({
        'status': 'ended',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// IDs der eigenen Sessions, die der Server noch als laufend führt.
  Future<List<String>> myActiveSessionIds() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('sessions')
          .select('id')
          .eq('host_id', me.id)
          .eq('status', 'active') as List<dynamic>;
      return [for (final r in rows) (r as Map)['id'] as String];
    } catch (_) {
      return const [];
    }
  }

  /// Eigene aktive Sessions mit allen Feldern — für den Abgleich zwischen
  /// Geräten. Ein Beacon, der am Telefon gestartet wurde, muss im Browser
  /// als der eigene erscheinen, nicht als fremder und schon gar nicht als
  /// „laeuft nichts".
  Future<List<Map<String, dynamic>>> myActiveSessions() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('sessions')
          .select('id, venue_id, venue_name, message, visibility, status, '
              'started_at, expires_at, ended_at, latitude, longitude')
          .eq('host_id', me.id)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());
      return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
    } catch (_) {
      return const [];
    }
  }

  /// Beendet serverseitig alles, was lokal nicht (mehr) läuft.
  ///
  /// Das ist die Reparatur für ein fehlgeschlagenes [endSession]: Ein
  /// Beacon, den der Nutzer beendet hat, der aber mangels Verbindung
  /// stehen blieb, verschwindet spätestens beim nächsten Abgleich.
  ///
  /// Nachziehen ist hier — anders als beim Verlängern — gefahrlos: Es
  /// verringert Sichtbarkeit immer, erhöht sie nie. Ein spät
  /// nachgereichtes Beenden kann nichts kaputt machen.
  ///
  /// Rückgabe: Anzahl der aufgeräumten Sessions.
  Future<int> endStaleSessions({String? keepSessionId}) async {
    final offen = await myActiveSessionIds();
    var beendet = 0;
    for (final id in offen) {
      if (id == keepSessionId) continue;
      if (await endSession(id)) beendet++;
    }
    return beendet;
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
    await for (final rows in client
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

  /// **Eine** Session am Server nachschlagen — unabhängig davon, ob sie
  /// gerade in der Freundesliste steht.
  ///
  /// **Warum das gefehlt hat.** Die Detailansicht kannte nur zwei Quellen:
  /// die lokale Datenbank (eigene Sessions) und die Liste der laufenden
  /// Freundes-Beacons. Alles andere endete bei „Session nicht gefunden“ —
  /// und „alles andere“ war mehr, als es klingt: die Session aus einer
  /// Benachrichtigung (die trägt eine blanke UUID, keinen `remote-`-Namen),
  /// eine Session aus dem Feed eines Freundes, und jede Session in den
  /// Sekunden, in denen der Realtime-Strom nach dem Bildschirmwechsel neu
  /// aufbaut und die Liste kurz leer ist.
  ///
  /// Was der Aufrufer sehen darf, entscheidet weiterhin allein die RLS
  /// (`sessions_select`, 0024): eigene Sessions immer, fremde nur
  /// **laufende** und nur für Freunde ab Kreis „Freund“ bzw. die Crew.
  /// `null` heißt deshalb zweierlei — vorbei oder nicht für dich —, und
  /// der Server sagt bewusst nicht, welches von beidem. Das ist kein
  /// Mangel dieser Methode, sondern der Zweck der Regel: Sonst wäre
  /// „gibt es nicht“ von „darfst du nicht“ unterscheidbar.
  ///
  /// **Offen für geplante Sessions (0048/0049):** Anders als
  /// [friendSessionsStream] filtert diese Methode **nicht** auf
  /// `status = 'active'` — sie liefert bewusst auch beendete eigene
  /// Sessions, damit die Detailansicht aus einer alten Benachrichtigung
  /// heraus noch etwas zeigt. Sobald die App Verabredungen anlegt, wird
  /// eine davon hier als laufender Beacon dargestellt. `RemoteSession`
  /// braucht dafür `status` und `scheduledFor`; heute ist das folgenlos,
  /// weil die App keine geplanten Sessions erzeugt. Siehe
  /// docs/features/39, Schritt 5.
  Future<RemoteSession?> byId(String sessionId) async {
    if (currentUser == null) return null;
    try {
      final row = await client
          .from('sessions')
          .select('id, host_id, venue_name, message, latitude, longitude, '
              'started_at, expires_at')
          .eq('id', sessionId)
          .maybeSingle();
      if (row == null) return null;
      return RemoteSession(
        id: row['id'] as String,
        host: await _fetchProfile(row['host_id'] as String),
        venueName: row['venue_name'] as String?,
        message: row['message'] as String?,
        latitude: (row['latitude'] as num?)?.toDouble(),
        longitude: (row['longitude'] as num?)?.toDouble(),
        startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
        expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<RemoteProfile> _fetchProfile(String id) async {
    try {
      final row = await client
          .from('profiles')
          .select(OnlineApi.profileCols)
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
          await client.rpc<dynamic>('count_other_active_sessions', params: {
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

  /// Wer auf dem Server zu dieser Session „Prost" oder „Bin dabei" gesagt
  /// hat. Fuer den Gastgeber: Seine lokale Datenbank kennt nur lokale
  /// Teilnehmer — bis 2026-09-03 sah er deshalb nie, dass jemand reagiert
  /// hatte, und beide Knoepfe wirkten funktionslos.
  Future<List<RemoteParticipant>> participantsOf(String sessionId) async {
    if (currentUser == null) return const [];
    try {
      final rows = await client
          .from('session_participants')
          .select('kind, profile:profiles!session_participants_profile_id_fkey('
              '${OnlineApi.profileCols})')
          .eq('session_id', sessionId);
      return [
        for (final r in rows)
          RemoteParticipant(
            profile: RemoteProfile.fromRow(r['profile'] as Map<String, dynamic>),
            art: teilnahmeAus(r['kind'] as String?),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// „Bin dabei" bzw. Zuprosten spiegeln.
  ///
  /// Fehler bleiben still, und das ist hier vertretbar: Lokal ist die
  /// Teilnahme vermerkt, es geht nichts verloren, und niemand trifft auf
  /// dieser Grundlage eine Entscheidung über Sichtbarkeit. Der Rückgabewert
  /// steht trotzdem zur Verfügung, damit ein Aufrufer es wissen KANN.
  Future<bool> joinSession(String sessionId, {required bool joined}) =>
      antworten(sessionId, joined ? Teilnahme.dabei : Teilnahme.prost);

  /// Auf einen Beacon antworten: dabei, keine Zeit oder nur Prost (0047).
  ///
  /// **Zusage und Absage schließen einander aus, Prost steht daneben.**
  /// Man kann aus der Ferne zuprosten *und* absagen — das ist sogar der
  /// häufigste Fall („kann heute nicht, trink eins auf mich“). Deshalb
  /// räumt eine Zu- oder Absage nur die jeweils andere weg, nie den Prost.
  ///
  /// Der Schlüssel der Tabelle ist `(session_id, profile_id, kind)`; ein
  /// bloßes `upsert` legte also eine **zweite** Zeile an, statt die alte zu
  /// ersetzen. Genau daran wäre „ich komme doch nicht“ gescheitert: Beide
  /// Antworten stünden nebeneinander und der Gastgeber sähe weiter eine
  /// Zusage.
  Future<bool> antworten(String sessionId, Teilnahme art) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      if (art != Teilnahme.prost) {
        await client
            .from('session_participants')
            .delete()
            .eq('session_id', sessionId)
            .eq('profile_id', me.id)
            .inFilter('kind', ['joined', 'declined']);
      }
      await client.from('session_participants').upsert({
        'session_id': sessionId,
        'profile_id': me.id,
        'kind': art.schluessel,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Alle Check-ins einer Runde, die ich sehen darf.
  ///
  /// Nötig, weil die lokale Datenbank nur die **eigenen** Check-ins
  /// kennt: Selbst in der eigenen Runde liegen die der anderen
  /// ausschließlich am Server. Ohne diesen Abruf zeigte die
  /// Runden-Ansicht dem Gastgeber nur, was er selbst getrunken hat.
  ///
  /// Was zurückkommt, entscheidet allein die RLS (`checkins_select`,
  /// 0050): Mitrundige sehen einander, Unbeteiligte nichts. Hier wird
  /// nichts gefiltert, was der Server nicht schon gefiltert hat.
  Future<List<RemoteCheckin>> sessionCheckins(String sessionId,
      {int limit = 100}) async {
    if (currentUser == null) return const [];
    try {
      final rows = await client
          .from('checkins')
          .select('id, beer_name, brewery_name, beer_style, is_alcohol_free, '
              'rating, note, venue_name, session_id, photo_url, created_at, '
              'author:profiles!checkins_profile_id_fkey('
              '${OnlineApi.profileCols})')
          .eq('session_id', sessionId)
          .order('created_at')
          .limit(limit);
      return [for (final r in rows) RemoteCheckin.fromRow(r)];
    } catch (_) {
      return const [];
    }
  }

  /// Die laufende **fremde** Runde, an der ich teilnehme — oder `null`.
  ///
  /// Für die Zuordnung beim Einchecken: Wer bei jemand anderem mittrinkt,
  /// soll seinen Check-in in dessen Runde wiederfinden. Bis 0.10.14 ging
  /// das nicht, weil `getMyActiveSession` nur eigene Runden kennt
  /// (`host_id = ich`).
  ///
  /// **Nur online zu beantworten.** Zusagen leben ausschließlich am
  /// Server; lokal gibt es keine Spur davon. Ohne Verbindung bleibt die
  /// Zuordnung deshalb aus — der Check-in selbst nicht. Das ist die
  /// bewusste Grenze, siehe docs/features/40.
  ///
  /// Gibt es mehrere, gewinnt die zuletzt begonnene: Wer an zwei Runden
  /// zusagt und dann eincheckt, meint mit größter Wahrscheinlichkeit die,
  /// die gerade läuft.
  Future<String?> myJoinedRoundId() async {
    final me = currentUser;
    if (me == null) return null;
    try {
      final rows = await client
          .from('session_participants')
          .select('session_id, sessions!inner(status, expires_at, started_at)')
          .eq('profile_id', me.id)
          .eq('kind', 'joined')
          .eq('sessions.status', 'active')
          .gt('sessions.expires_at', DateTime.now().toUtc().toIso8601String())
          .order('started_at', referencedTable: 'sessions', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return rows.first['session_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Die eigene Antwort auf einen Beacon zurücknehmen („doch nicht“).
  Future<bool> antwortZuruecknehmen(String sessionId) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      await client
          .from('session_participants')
          .delete()
          .eq('session_id', sessionId)
          .eq('profile_id', me.id)
          .inFilter('kind', ['joined', 'declined']);
      return true;
    } catch (_) {
      return false;
    }
  }
}
