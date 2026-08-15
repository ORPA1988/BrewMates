part of '../providers.dart';

// Feed, Tagebuch, Toasts, Kommentare
//
// Teil von `providers.dart` (Backlog B-4). Als `part`, nicht als
// eigene Bibliothek: Die Provider greifen auf gemeinsame private
// Helfer zu (`_now`, `_syncTickProvider`). Ein `part` teilt den
// Namensraum, ein Import nicht — sonst muessten interne Details
// oeffentlich werden, nur damit die Datei kleiner wird.

// ============================================================================
// Feed, Toasts, Kommentare
// ============================================================================

/// Grenzen der Beacon-Laufzeit. Kürzer als eine halbe Stunde ergibt keine
/// Einladung, länger als zwölf Stunden ist fast immer ein vergessener
/// Beacon — und ein Beacon, der aus Versehen stehen bleibt, ist ein
/// Datenschutzproblem, kein Komfortmerkmal. Beide Grenzen werden
/// serverseitig nochmals geprüft (Migration 0021).
const minSessionDuration = Duration(minutes: 30);
const maxSessionDuration = Duration(hours: 12);

/// Hält eine Laufzeit in den erlaubten Grenzen. Rein und testbar.
Duration clampSessionDuration(Duration d) {
  if (d < minSessionDuration) return minSessionDuration;
  if (d > maxSessionDuration) return maxSessionDuration;
  return d;
}

/// Zur Auswahl stehende Laufzeiten.
const sessionDurationChoices = <Duration>[
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 3),
  Duration(hours: 5),
  Duration(hours: 8),
  Duration(hours: 12),
];

/// Zuletzt gewählte Laufzeit — Vorgabe für den nächsten Beacon,
/// insbesondere für den Ein-Tap-Beacon, der nicht fragen soll.
/// Ohne eigene Wahl bleibt es bei drei Stunden wie bisher.
final preferredSessionDurationProvider =
    StateProvider<Duration>((ref) => const Duration(hours: 3));

/// Seitengröße für Feed und Tagebuch. Beide laden zunächst eine Seite und
/// erweitern das Fenster, sobald der Mensch ans Ende scrollt — ohne
/// Obergrenze würde jeder Check-in eines ganzen Bierlebens auf einmal
/// gelesen und gebaut.
const feedPageSize = 30;

/// Aktuelles Fenster des Feeds (wächst um [feedPageSize] je „mehr laden").
final feedLimitProvider = StateProvider<int>((ref) {
  // Neue Anmeldung = neuer Feed: Fenster zurücksetzen.
  ref.watch(onlineUserProvider);
  return feedPageSize;
});

/// Aktuelles Fenster des Tagebuchs.
final diaryLimitProvider = StateProvider<int>((ref) => feedPageSize);

/// Feed: abgemeldet = lokale Daten inkl. Demo-Freunde; angemeldet = eigene
/// lokale Check-ins + die echter Freunde (Demo-Inhalte verschwinden).
final feedProvider = StreamProvider<List<CheckinDetails>>((ref) {
  final db = ref.watch(databaseProvider);
  final limit = ref.watch(feedLimitProvider);
  if (!ref.watch(isSignedInProvider)) return db.watchFeed(limit: limit);
  final remote = ref.watch(remoteFeedProvider).valueOrNull ?? const [];
  return db.watchFeed(limit: limit).map((locals) {
    final merged = [
      ...locals.where((c) => c.author.isMe),
      ...remote.map(remoteCheckinToDetails),
    ]..sort((a, b) => b.checkin.createdAt.compareTo(a.checkin.createdAt));
    // Eigene und fremde Einträge kommen aus zwei Quellen mit je eigenem
    // Fenster – nach dem Mischen auf die Seitengröße stutzen, sonst
    // springt die Länge unvorhersehbar.
    return merged.length > limit ? merged.sublist(0, limit) : merged;
  });
});

/// Suchbegriff des Tagebuchs. Liegt im Provider statt im Bildschirm,
/// damit die Suche in die Abfrage wandern kann.
final diarySearchProvider = StateProvider<String>((ref) => '');

final myDiaryProvider = StreamProvider<List<CheckinDetails>>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchFeed(
        onlyProfileId: me.id,
        limit: ref.watch(diaryLimitProvider),
        search: ref.watch(diarySearchProvider),
      );
});

/// Gesamtzahl eigener Check-ins — für „alles geladen?" und Statistiken.
final myCheckinCountProvider = StreamProvider<int>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(0);
  return ref.watch(databaseProvider).watchCheckinCount(me.id);
});

/// Lokale Check-ins, die noch nicht im Online-Konto liegen – z. B. weil sie
/// offline entstanden sind (null = Status gerade nicht feststellbar).
final pendingCheckinUploadProvider =
    FutureProvider<List<CheckinDetails>?>((ref) async {
  if (!ref.watch(isSignedInProvider)) return null;
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return null;
  // Bewusst der ungekürzte Bestand, NICHT das Tagebuch-Fenster: Sonst
  // bliebe genau der alte, offline entstandene Check-in unentdeckt, für
  // den es den Assistenten gibt.
  final mine = await ref.watch(databaseProvider).myCheckinsDetailed(me.id);
  final candidates = [
    for (final d in mine)
      if (CheckinsApi.isUploadable(d)) d,
  ];
  if (candidates.isEmpty) return const [];
  final remoteIds = await online.checkins.myRemoteCheckinIds();
  if (remoteIds == null) return null;
  return [
    for (final d in candidates)
      // Neu (kennt der Server nicht) ODER lokal korrigiert (Funktion 27).
      // Ohne den zweiten Fall käme eine Korrektur an einem bereits
      // hochgeladenen Check-in nie an — und die App zeigte etwas anderes
      // als die Freunde sehen.
      if (!remoteIds.contains(d.checkin.id) || d.checkin.dirty) d,
  ];
});

/// 30-Sekunden-Uhr auf einen 5-Minuten-Sync-Takt heruntergeteilt: Der Wert
/// ändert sich nur alle 5 Minuten, Abhängige laufen also nicht bei jedem
/// Uhr-Tick neu.
final _syncTickProvider = Provider<int>((ref) {
  final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  return now.millisecondsSinceEpoch ~/ (5 * 60 * 1000);
});
