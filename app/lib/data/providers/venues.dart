part of '../providers.dart';

// Gasthaeuser
//
// Teil von `providers.dart` (Backlog B-4). Als `part`, nicht als
// eigene Bibliothek: Die Provider greifen auf gemeinsame private
// Helfer zu (`_now`, `_syncTickProvider`). Ein `part` teilt den
// Namensraum, ein Import nicht — sonst muessten interne Details
// oeffentlich werden, nur damit die Datei kleiner wird.

// ============================================================================
// Gasthäuser (gemeinsame Datenbank; Cache in Drift, Wahrheit in Supabase)
// ============================================================================

final venueSyncServiceProvider =
    Provider<VenueSync>((ref) => VenueSync(ref.watch(databaseProvider)));

/// Automatischer Cache-Abgleich der Gasthaus-DB: bei Anmeldung und im
/// 5-Minuten-Takt (gleicher Takt wie der Check-in-Sync); die AppShell hält
/// den Provider am Leben. Rückgabe: zuletzt übernommene Zeilen.
final venueSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(_syncTickProvider);
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return 0;
  final imported = await ref.read(venueSyncServiceProvider).sync(online);
  return imported;
});

final venuesWithLocationProvider = StreamProvider<List<Venue>>(
    (ref) => ref.watch(databaseProvider).watchVenuesWithLocation());
