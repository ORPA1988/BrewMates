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

/// Verabredungen, die ich sehen darf — meine und die von Freunden.
///
/// **Nur vom Server**, weil es sie lokal nicht gibt: Eine Verabredung,
/// von der niemand erfährt, ist keine (anders als ein Beacon, der auch
/// offline als Zustand Sinn ergibt). Ohne Verbindung ist die Liste leer,
/// und das ist die Wahrheit, nicht ein Fehler.
///
/// Am 30-Sekunden-Takt: Eine Zusage oder eine neue Verabredung soll nicht
/// bis zum nächsten Bildschirmwechsel warten.
final plannedSessionsProvider =
    FutureProvider<List<RemoteSession>>((ref) async {
  ref.watch(onlineUserProvider);
  ref.watch(clockProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return const [];
  return online.sessions.plannedSessions();
});

/// Die Check-ins einer Runde, wie der Server sie kennt.
///
/// Auffrischung am 30-Sekunden-Takt: Eine Runde ist ein laufender Abend,
/// und wer gerade etwas eingecheckt hat, soll nicht erst beim nächsten
/// Bildschirmwechsel auftauchen.
final _sessionCheckinsRemoteProvider =
    FutureProvider.autoDispose.family<List<CheckinDetails>, String>(
        (ref, id) async {
  ref.watch(clockProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return const [];
  final rows = await online.sessions.sessionCheckins(stripRemote(id));
  return [for (final r in rows) remoteCheckinToDetails(r)];
});

/// Alle Check-ins einer Runde — die eigenen aus der lokalen Datenbank,
/// die der anderen vom Server.
///
/// **Warum beides.** Lokal stehen nur die eigenen Check-ins; selbst in
/// der eigenen Runde liegen die der Mitrundigen ausschließlich am
/// Server. Vorher gab dieser Provider für fremde Runden schlicht eine
/// leere Liste zurück — die Detailansicht einer fremden Runde zeigte
/// also nie etwas, und die eigene zeigte nur einen selbst.
///
/// Der lokale Zweig bleibt trotzdem: Er ist sofort da, funktioniert
/// offline und zeigt einen gerade angelegten Check-in, bevor der Upload
/// durch ist.
final sessionCheckinsProvider =
    StreamProvider.family<List<CheckinDetails>, String>((ref, id) {
  final vomServer =
      ref.watch(_sessionCheckinsRemoteProvider(id)).valueOrNull ?? const [];
  final lokal = isRemoteId(id)
      ? Stream.value(const <CheckinDetails>[])
      : ref.watch(databaseProvider).watchSessionCheckins(id);
  return lokal.map((eigene) => rundeVereinen(eigene, vomServer));
});

/// Führt lokale und Server-Check-ins zusammen.
///
/// Der eigene Check-in steht in beiden Quellen. Die **lokale** Fassung
/// gewinnt: Sie trägt Bier und Brauerei als vollständige Datensätze,
/// während die Server-Zeile nur denormalisierte Namen kennt.
///
/// **Der Schlüssel ist die blanke UUID, nicht die ID.** Dieselbe Zeile
/// heißt lokal `abc` und vom Server `remote-abc` —
/// `remoteCheckinToDetails` setzt das Präfix, damit fremde und eigene
/// Datensätze nicht kollidieren. Ohne `stripRemote` griffe die
/// Entdopplung deshalb nie, und der eigene Check-in stünde zweimal in
/// der Runde: einmal mit Bierdatensatz, einmal nur mit Namen.
List<CheckinDetails> rundeVereinen(
  List<CheckinDetails> lokal,
  List<CheckinDetails> vomServer,
) {
  final nachId = <String, CheckinDetails>{
    for (final c in vomServer) stripRemote(c.checkin.id): c,
    for (final c in lokal) stripRemote(c.checkin.id): c,
  };
  return nachId.values.toList()
    ..sort((a, b) => a.checkin.createdAt.compareTo(b.checkin.createdAt));
}
