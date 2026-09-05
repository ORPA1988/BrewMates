part of '../providers.dart';

// Challenges und Sitzungs-Abgleich
//
// Teil von `providers.dart` (Backlog B-4). Als `part`, nicht als
// eigene Bibliothek: Die Provider greifen auf gemeinsame private
// Helfer zu (`_now`, `_syncTickProvider`). Ein `part` teilt den
// Namensraum, ein Import nicht — sonst muessten interne Details
// oeffentlich werden, nur damit die Datei kleiner wird.

// ============================================================================
// Challenges (Herausforderungen mit Belohnungs-Badge, Admin-gepflegt)
// ============================================================================

/// Holt Challenges online, aktualisiert den Offline-Cache und liefert die
/// Cache-Zeilen (offline: nur Cache). Aktualisiert bei Anmeldung und im
/// 5-Minuten-Takt.
final challengesProvider =
    FutureProvider<List<ChallengeCacheData>>((ref) async {
  ref.watch(_syncTickProvider);
  ref.watch(onlineUserProvider);
  final db = ref.watch(databaseProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online != null && online.currentUser != null) {
    final rows = await online.listChallenges();
    if (rows != null) {
      await db.upsertChallengeCache([
        for (final r in rows)
          ChallengeCacheCompanion(
            id: Value(r['id'] as String),
            title: Value(r['title'] as String),
            description: Value((r['description'] as String?) ?? ''),
            emoji: Value((r['emoji'] as String?) ?? '🏆'),
            ruleJson: Value(json.encode(r['rule'])),
            startsAt:
                Value(DateTime.parse(r['starts_at'] as String).toLocal()),
            endsAt: Value(DateTime.parse(r['ends_at'] as String).toLocal()),
          ),
      ]);
    }
  }
  return db.allCachedChallenges();
});

/// Fortschritt aller aktiven Challenges (abgeschlossene behalten Häkchen).
final challengeProgressProvider =
    FutureProvider<List<ChallengeProgress>>((ref) async {
  final me = await ref.watch(meProvider.future);
  ref.watch(myDiaryProvider);
  ref.watch(myBadgesProvider);
  await ref.watch(challengesProvider.future);
  return ChallengeEngine(ref.watch(databaseProvider)).progressList(me.id);
});

/// Verdiente Challenge-Trophäen für die Abzeichen-Galerie; Titel/Emoji
/// kommen aus dem Challenge-Cache (funktioniert auch nach Challenge-Ende).
final earnedChallengeBadgesProvider = FutureProvider<
    List<({String emoji, String title, DateTime awardedAt})>>((ref) async {
  final me = await ref.watch(meProvider.future);
  ref.watch(myBadgesProvider);
  final db = ref.watch(databaseProvider);
  final rows = await db.earnedChallengeBadges(me.id);
  if (rows.isEmpty) return const [];
  final cache = await db.allCachedChallenges();
  return [
    for (final row in rows)
      () {
        final idPrefix = row.badgeSlug.substring('challenge-'.length);
        for (final c in cache) {
          if (c.id.startsWith(idPrefix)) {
            return (
              emoji: c.emoji,
              title: c.title,
              awardedAt: row.awardedAt,
            );
          }
        }
        return (
          emoji: '🏆',
          title: 'Challenge',
          awardedAt: row.awardedAt,
        );
      }(),
  ];
});

/// Automatischer Konto-Abgleich: überträgt offline entstandene Check-ins,
/// sobald Konto und Verbindung da sind – bei Anmeldung, nach jedem lokalen
/// Check-in (Tagebuch-Stream) und alle 5 Minuten als Nachzügler-Retry.
/// Dank Upsert über die Client-UUIDs idempotent; die AppShell hält den
/// Provider am Leben. Rückgabe: zuletzt übertragene Anzahl.
final checkinAutoSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return 0;
  final pending =
      await ref.watch(pendingCheckinUploadProvider.future) ?? const [];
  if (pending.isEmpty) return 0;
  final uploaded = await online.checkins.uploadLocalCheckins(pending) ?? 0;
  if (uploaded > 0) {
    // Angekommen heißt: wieder deckungsgleich mit dem Server. Bliebe das
    // Flag stehen, lüde der Abgleich dieselben Zeilen bis in alle Ewigkeit
    // erneut hoch.
    await ref
        .read(databaseProvider)
        .markCheckinsClean([for (final d in pending) d.checkin.id]);
    ref.invalidate(pendingCheckinUploadProvider);
  }
  return uploaded;
});

/// Räumt Beacons auf, die der Server noch als laufend führt, obwohl lokal
/// keiner (mehr) läuft.
///
/// Das ist die Reparatur für ein fehlgeschlagenes Beenden: Ohne Verbindung
/// bleibt die Session auf dem Server stehen und zeigt Freunden weiter den
/// Aufenthaltsort. Läuft am selben Takt wie der Check-in-Abgleich.
///
/// Nachziehen ist hier gefahrlos — anders als beim Verlängern verringert
/// es Sichtbarkeit immer und erhöht sie nie.
final sessionReconcileProvider = FutureProvider<int>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return 0;
  final db = ref.watch(databaseProvider);
  final me = await ref.watch(meProvider.future);
  final now = DateTime.now();

  // Bis 2026-09-02 stand hier: „Beende am Server alles, was lokal nicht
  // laeuft." Das klang nach Aufraeumen und war eine Falle: Jedes Geraet
  // hat seine eigene lokale Datenbank. Ein im Browser geoeffnetes
  // BrewMates kannte den am Telefon gestarteten Beacon nicht — und
  // beendete ihn. Der Mensch sah auf keinem Geraet mehr etwas und hielt
  // es fuer einen Synchronisationsfehler. Es war eine Loeschung.
  //
  // Jetzt gilt die Umkehrung:
  //   1. Was am Server laeuft und hier fehlt, wird UEBERNOMMEN.
  //   2. Beendet wird am Server nur, was hier nachweislich BEENDET ist —
  //      also eine lokale Zeile mit Status `ended`. Unbekanntes bleibt
  //      unangetastet: Es koennte das andere Geraet sein.
  var geaendert = 0;
  final remote = await online.sessions.myActiveSessions();
  for (final r in remote) {
    final id = r['id'] as String;
    final lokal = await db.getSession(id);
    if (lokal == null) {
      await db.upsertSession(SessionsCompanion.insert(
        id: id,
        hostId: me.id,
        venueId: Value(r['venue_id'] as String?),
        venueName: Value(r['venue_name'] as String?),
        message: Value(r['message'] as String?),
        visibility: r['visibility'] == 'crew'
            ? SessionVisibility.crew
            : SessionVisibility.friends,
        status: SessionStatus.active,
        startedAt: DateTime.parse(r['started_at'] as String).toLocal(),
        expiresAt: DateTime.parse(r['expires_at'] as String).toLocal(),
        latitude: Value((r['latitude'] as num?)?.toDouble()),
        longitude: Value((r['longitude'] as num?)?.toDouble()),
      ));
      geaendert++;
    } else if (lokal.status == SessionStatus.ended ||
        !lokal.expiresAt.isAfter(now)) {
      // Lokal beendet oder abgelaufen, am Server noch aktiv: Das ist der
      // Fall eines fehlgeschlagenen endSession — nachziehen ist gefahrlos,
      // es verringert Sichtbarkeit, erhoeht sie nie.
      if (await online.sessions.endSession(id)) geaendert++;
    }
  }
  return geaendert;
});

/// 👥 Eigene Crews (Beitritt per Einladungscode = Crew-UUID).
final myCrewsProvider = FutureProvider<List<RemoteCrew>>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return const [];
  return online.myCrews();
});

/// Mitglieder einer Crew (null = offline).
final crewMembersProvider = FutureProvider.autoDispose
    .family<List<({RemoteProfile profile, String role})>?, String>(
        (ref, crewId) async {
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;
  return online.crewMembers(crewId);
});

/// 🍺 Freunde mit Bierlaune, wie der Server sie zuletzt kannte.
///
/// **Das ist der Provider zum Entwerten**, nicht [thirstyFriendsProvider]:
/// Der ist abgeleitet und holt von sich aus nichts nach. Wer ihn
/// entwertet, bewirkt nichts — und merkt es nicht.
final thirstyFriendsAbrufProvider =
    FutureProvider<List<RemoteProfile>>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return const [];
  // Seit 0024 filtert der Server nach Freundeskreis: Bekannte sehen die
  // Bierlaune nicht. Vorher wurde die ganze Freundesliste geholt und in
  // der App gefiltert — die Angabe lag damit auf jedem Gerät, das
  // danach fragte.
  return online.friends.thirstyFriends();
});

/// 🍺 Freunde, die **jetzt** Bierlaune haben — „X hätte Lust auf ein Bier".
///
/// Der Server filtert beim Abruf, aber abgerufen wird nur alle fünf
/// Minuten. Eine abgelaufene Bierlaune blieb deshalb bis zu fünf Minuten
/// stehen — und das ist die eine Angabe, bei der „schon vorbei" das
/// Gegenteil von hilfreich ist: Man macht sich auf den Weg zu jemandem,
/// der längst zu Hause ist. Der Zeitfilter hängt hier am
/// 30-Sekunden-Takt.
///
/// **Diesen hier ansehen, [thirstyFriendsAbrufProvider] entwerten.**
final thirstyFriendsProvider = Provider<List<RemoteProfile>>((ref) {
  final jetzt = _now(ref);
  final roh = ref.watch(thirstyFriendsAbrufProvider).valueOrNull ?? const [];
  return [
    for (final f in roh)
      if (f.thirstyUntil != null && f.thirstyUntil!.isAfter(jetzt)) f,
  ];
});

/// Eigene Bierlaune (kommt seit 0024 über eine Funktion, weil das
/// Spaltenrecht auf `thirsty_until` entzogen ist).
final myThirstyUntilProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(_syncTickProvider);
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  return online?.friends.myThirstyUntil();
});

/// Die eigene Voreinstellung für die Sichtbarkeit neuer Check-ins.
///
/// Kommt über eine RPC und nicht aus der Profilzeile: Ein Spaltenrecht
/// hätte sie auch Freunden und Crew-Mitgliedern gezeigt (0059,
/// Funktion 44). Ohne Konto oder Verbindung bleibt es bei `friends` —
/// derselbe Wert, den auch der Server als Vorgabe führt.
final myDefaultVisibilityProvider =
    FutureProvider<SessionVisibility>((ref) async {
  ref.watch(_syncTickProvider);
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  return await online?.myDefaultVisibility() ?? SessionVisibility.friends;
});

/// Läuft meine Bierlaune gerade noch?
///
/// Getrennt vom Abrufen, weil beides verschiedene Takte hat: Der Wert
/// kommt alle fünf Minuten vom Server, die Frage „gilt er noch" stellt
/// sich jede halbe Minute. Ohne diese Trennung zeigte der Knopf auf der
/// Startseite bis zu fünf Minuten lang „Bierlaune bis 18:30", obwohl es
/// längst 18:32 war.
final bierlauneAktivProvider = Provider<bool>((ref) {
  final bis = ref.watch(myThirstyUntilProvider).valueOrNull;
  return bis != null && bis.isAfter(_now(ref));
});

/// Merker, für welches Konto der Cloud-Restore diese App-Sitzung schon
/// vollständig gelaufen ist (verhindert Doppel-Läufe).
final _restoredUidProvider = StateProvider<String?>((_) => null);

/// ☁️ Cloud-Restore (Migration 0016): holt nach der Anmeldung eigene
/// Check-ins, Erfolge und Wunschliste vom Server zurück und vereinigt sie
/// mit dem lokalen Bestand — wichtig nach Neuinstallation/Gerätewechsel.
/// Läuft einmal pro Konto und App-Sitzung; solange er offline
/// unvollständig bleibt, versucht es der 5-Minuten-Takt erneut.
/// Die AppShell hält den Provider am Leben.
final cloudRestoreProvider = FutureProvider<RestoreSummary?>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  final user = ref.watch(onlineUserProvider).valueOrNull;
  if (online == null || user == null) return null;
  if (ref.read(_restoredUidProvider) == user.id) return null;
  final db = ref.read(databaseProvider);
  final summary = await restoreFromCloud(
    db,
    fetchCheckinIds: online.checkins.myRemoteCheckinIds,
    fetchCheckinsByIds: online.checkins.checkinsByIds,
    fetchBadges: online.checkins.myRemoteBadges,
    pushBadges: online.checkins.uploadBadges,
    fetchWishlist: online.checkins.myRemoteWishlist,
    pushWishlistItem: (key) => online.checkins.setWishlistRemote(key, add: true),
  );
  if (summary.complete) {
    ref.read(_restoredUidProvider.notifier).state = user.id;
  }
  if (summary.checkins > 0) {
    // Wiederhergestellte Check-ins können weitere Abzeichen auslösen.
    await ref.read(actionsProvider).evaluateBadges();
  }
  return summary;
});

final toastCountProvider = StreamProvider.family<int, String>(
    (ref, checkinId) => ref.watch(databaseProvider).watchToastCount(checkinId));

final toastedByMeProvider =
    StreamProvider.family<bool, String>((ref, checkinId) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(false);
  return ref.watch(databaseProvider).watchToastedByMe(checkinId, me.id);
});

final commentCountProvider = StreamProvider.family<int, String>((ref,
        checkinId) =>
    ref.watch(databaseProvider).watchCommentCount(checkinId));

final commentsProvider =
    StreamProvider.family<List<(Comment, Profile)>, String>((ref, checkinId) =>
        ref.watch(databaseProvider).watchComments(checkinId));

/// Server-Check-in-UUID zu einer Feed-ID: `remote-…`-Präfix entfernen;
/// null, wenn der Eintrag nie hochgeladen wurde (Demo/Seed ohne UUID).
String? serverCheckinId(String feedId) {
  final real = stripRemote(feedId);
  return isUuid(real) ? real : null;
}

/// 🍻 Server-Reaktionen (Toasts + Kommentare) für alle Feed-Einträge in
/// EINER Abfrage – gilt für eigene hochgeladene Check-ins genauso wie für
/// die der Freunde. null = offline/abgemeldet (Karte fällt auf die
/// lokalen Zähler zurück); aktualisiert sich im 5-Minuten-Takt und nach
/// jeder eigenen Aktion (Invalidate in BrewActions).
final feedReactionsProvider = FutureProvider<
    Map<String, ({int toasts, bool toastedByMe, int comments})>?>((ref) async {
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return null;
  final feed = await ref.watch(feedProvider.future);
  final ids = <String>[
    for (final d in feed)
      if (serverCheckinId(d.checkin.id) case final id?) id,
  ];
  return online.checkins.reactionsFor(ids);
});

/// Kommentare eines Server-Check-ins (für das Kommentar-Sheet).
final remoteCommentsProvider = FutureProvider.autoDispose.family<
    List<({RemoteProfile author, String body, DateTime createdAt})>?,
    String>((ref, checkinId) async {
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;
  return online.checkins.commentsRemote(checkinId);
});
