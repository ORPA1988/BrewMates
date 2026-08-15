part of '../providers.dart';

// Nachtraege, Update-Pruefung, Vertrauensstufen
//
// Teil von `providers.dart` (Backlog B-4). Als `part`, nicht als
// eigene Bibliothek: Die Provider greifen auf gemeinsame private
// Helfer zu (`_now`, `_syncTickProvider`). Ein `part` teilt den
// Namensraum, ein Import nicht — sonst muessten interne Details
// oeffentlich werden, nur damit die Datei kleiner wird.

// ============================================================================
// Gelöschte Check-ins nachtragen (eigene Warteschlange, siehe Funktion 19)
// ============================================================================

/// Überträgt lokal gelöschte Check-ins an den Server – im selben Takt wie
/// der Gasthaus-Abgleich, aber unabhängig davon. Die AppShell hält den
/// Provider am Leben. Rückgabe: übertragene Löschungen.
final checkinDeleteSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(_syncTickProvider);
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return 0;
  return replayCheckinDeleteQueue(
    ref.read(databaseProvider),
    deleteRemote: online.checkins.deleteCheckinRemote,
    deletePhoto: online.checkins.deleteCheckinPhoto,
  );
});

/// Alle Gasthäuser aus dem Cache (Gasthausliste; Sortierung macht die UI).
final allVenuesProvider = StreamProvider<List<Venue>>(
    (ref) => ref.watch(databaseProvider).watchAllVenues());

final venueSearchProvider = StreamProvider.family<List<Venue>, String>(
    (ref, query) => ref.watch(databaseProvider).watchVenueSearch(query));

final venueProvider = StreamProvider.family<Venue?, String>(
    (ref, id) => ref.watch(databaseProvider).watchVenue(id));

// ============================================================================
// Automatischer Update-Check (GitHub-Releases; nur Android relevant)
// ============================================================================

/// Prüft einmal pro App-Start, ob ein neueres Release existiert.
/// null = aktuell/offline/kein Android. In Tests via override abschaltbar.
final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  // kIsWeb MUSS zuerst stehen: Im Browser meldet defaultTargetPlatform das
  // Betriebssystem des Geräts — auf Web gibt es aber kein APK-Update.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final client = http.Client();
  try {
    return await checkForUpdate(client,
        currentVersion: AppConfig.appVersion);
  } finally {
    client.close();
  }
});

/// Update-Hinweis auf Home wurde weggewischt (bis zum nächsten App-Start).
final updateDismissedProvider = StateProvider<bool>((ref) => false);

// ============================================================================
// Vertrauensstufen (Account-Levelsystem, Migration 0013)
// ============================================================================

/// Merkt sich die zuletzt gesehene Stufe, um Aufstiege zu erkennen.
final _lastSeenLevelProvider = StateProvider<int?>((ref) => null);

/// Eigene Vertrauensstufe + Punkte (null = offline/abgemeldet). Bei einem
/// Aufstieg wird ein [CelebrationItem] in [levelUpProvider] hinterlegt.
final accountLevelProvider =
    FutureProvider<({int level, int points})?>((ref) async {
  ref.watch(onlineUserProvider);
  ref.watch(myDiaryProvider); // Punkte ändern sich mit Check-ins
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return null;
  final info = await online.myAccountLevelInfo();
  if (info != null) {
    final last = ref.read(_lastSeenLevelProvider);
    if (last != null && info.level > last && info.level >= 2) {
      ref.read(levelUpProvider.notifier).state = CelebrationItem(
        emoji: levelEmoji(info.level),
        name: levelName(info.level),
        description:
            'Neue Vertrauensstufe erreicht – danke für deine Datenpflege!',
        headline: 'Stufenaufstieg! 🎖',
      );
    }
    ref.read(_lastSeenLevelProvider.notifier).state = info.level;
  }
  return info;
});

/// Wartende Level-Up-Feier; die UI konsumiert und leert den Wert.
final levelUpProvider = StateProvider<CelebrationItem?>((ref) => null);

/// 🏅 Datenpflege-Bestenliste (Top 20; leer offline/abgemeldet).
final leaderboardProvider = FutureProvider<
    List<({String username, String avatarEmoji, int points})>>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.contributionLeaderboard();
});

/// Muss der Nutzer aktualisieren, bevor die App weiterläuft?
///
/// Der Riegel aus Migration 0029. Er greift nur bei einer klaren Antwort
/// des Servers — offline, abgemeldet oder ohne gesetzten Wert läuft die
/// App normal weiter (siehe `core/min_version.dart`).
final updatePflichtProvider = FutureProvider<bool>((ref) async {
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return false;
  final min = await online.minSupportedVersion();
  return istUpdatePflicht(
    appVersion: AppConfig.appVersion,
    minVersion: min,
  );
});
