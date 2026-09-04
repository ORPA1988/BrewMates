part of '../providers.dart';

// Beacons
//
// Teil von `providers.dart` (Backlog B-4). Als `part`, nicht als
// eigene Bibliothek: Die Provider greifen auf gemeinsame private
// Helfer zu (`_now`, `_syncTickProvider`). Ein `part` teilt den
// Namensraum, ein Import nicht — sonst muessten interne Details
// oeffentlich werden, nur damit die Datei kleiner wird.

// ============================================================================
// Sessions
// ============================================================================

/// Aktive Sessions: abgemeldet = lokal (inkl. Demo); angemeldet = eigene
/// aktive Session + Live-Sessions echter Freunde.
final activeSessionsProvider = StreamProvider<List<SessionDetails>>((ref) {
  final localStream =
      ref.watch(databaseProvider).watchActiveSessions(_now(ref));
  if (!ref.watch(isSignedInProvider)) return localStream;
  final remote = ref.watch(remoteSessionsProvider);
  return localStream.map((locals) => [
        ...locals.where((s) => s.host.isMe),
        ...remote.map(remoteSessionToDetails),
      ]);
});

final myActiveSessionProvider = StreamProvider<Session?>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(null);
  return ref.watch(databaseProvider).watchMyActiveSession(me.id, _now(ref));
});

/// Eine einzelne Session — egal, woher man kommt.
///
/// **Der Fehler, den das behebt.** Vorher gab es genau zwei Quellen: die
/// lokale Datenbank und die Liste der gerade laufenden Freundes-Beacons.
/// Wer über einen anderen Weg hier ankam, sah „Session nicht gefunden“ —
/// und die anderen Wege sind die häufigen:
///
/// - Aus der **Glocke** oder einem Push: Die Benachrichtigung trägt die
///   blanke Server-UUID, kein `remote-` davor. Der Aufruf landete damit im
///   Zweig für *eigene* Sessions und fragte die lokale Datenbank nach
///   einer fremden Session — die dort natürlich nie steht.
/// - Aus dem **Feed eines Freundes**.
/// - Und schlicht **zu früh**: Der Realtime-Strom baut beim
///   Bildschirmwechsel neu auf; in diesen Sekunden ist die Liste leer.
///
/// Deshalb jetzt drei Quellen mit klarer Reihenfolge — lokal, Liste,
/// Server — und die letzte beantwortet alle drei Fälle auf einmal.
///
/// Bleibt am Ende `null`, heißt das **nicht** „gibt es nicht“: Die RLS
/// zeigt fremde Sessions nur, solange sie laufen. Vorbei und „nicht für
/// dich“ sehen von hier aus gleich aus, und das ist Absicht (0024). Der
/// Bildschirm muss deshalb beides zugleich sagen.
final sessionProvider =
    StreamProvider.family<SessionDetails?, String>((ref, id) async* {
  final uuid = stripRemote(id);

  if (isRemoteId(id)) {
    for (final s in ref.watch(remoteSessionsProvider)) {
      if (s.id == uuid) {
        yield remoteSessionToDetails(s);
        return;
      }
    }
    yield await _vomServer(ref, uuid);
    return;
  }

  // Eigene Sessions tragen dieselbe ID wie ihr Zwilling am Server
  // (`upsertSession` schreibt `session.id`), also ist die lokale Datenbank
  // hier die richtige erste Frage — sie ist sofort da und lebt mit.
  SessionDetails? ausDemNetz;
  var gefragt = false;
  await for (final lokal in ref.watch(databaseProvider).watchSession(id)) {
    if (lokal != null) {
      yield lokal;
      continue;
    }
    // Genau einmal nachfragen. Der lokale Strom meldet sich bei jeder
    // Änderung der Tabelle wieder; ohne die Sperre löste jede fremde
    // Session-Änderung einen neuen Serveraufruf aus.
    if (!gefragt) {
      gefragt = true;
      ausDemNetz = await _vomServer(ref, uuid);
    }
    yield ausDemNetz;
  }
});

Future<SessionDetails?> _vomServer(Ref ref, String uuid) async {
  final online = await ref.watch(onlineServiceProvider.future);
  final session = await online?.sessions.byId(uuid);
  return session == null ? null : remoteSessionToDetails(session);
}

final sessionCheckinsProvider =
    StreamProvider.family<List<CheckinDetails>, String>((ref, id) {
  if (isRemoteId(id)) return Stream.value(const []);
  return ref.watch(databaseProvider).watchSessionCheckins(id);
});
