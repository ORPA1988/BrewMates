part of '../providers.dart';

// Barcode-Suche, Standort, Profil, Freunde (lokal)
//
// Teil von `providers.dart` (Backlog B-4). Als `part`, nicht als
// eigene Bibliothek: Die Provider greifen auf gemeinsame private
// Helfer zu (`_now`, `_syncTickProvider`). Ein `part` teilt den
// Namensraum, ein Import nicht — sonst muessten interne Details
// oeffentlich werden, nur damit die Datei kleiner wird.

// ============================================================================
// Hero-Funktionen: Barcode-Lookup & Standort
// ============================================================================

final barcodeLookupProvider = Provider<BarcodeLookup>((ref) => BarcodeLookup(
      ref.watch(databaseProvider),
      // Zwischenschritt der Scan-Kette: von anderen Nutzern direkt
      // eingetragene Community-Biere (nur angemeldet erreichbar).
      communityLookup: (ean) async {
        final online = await ref.read(onlineServiceProvider.future);
        return online?.communityBeerByBarcode(ean);
      },
    ));

/// Echte Community-Bewertung (Ø + Anzahl) aus den Online-Check-ins aller
/// Nutzer – ersetzt schrittweise die redaktionelle community_rating.
final onlineRatingStatsProvider =
    FutureProvider.family<(double, int)?, String>((ref, beerId) async {
  if (!ref.watch(isSignedInProvider)) return null;
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;
  final item = await ref.watch(beerProvider(beerId).future);
  if (item == null) return null;
  return online.beerRatingStats(item.beer.name, item.brewery.name);
});

/// In Widget-Tests per overrideWithValue durch einen Fake ersetzen.
final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

// ============================================================================
// Profil & Freunde
// ============================================================================

final meProvider = StreamProvider<Profile>(
    (ref) => ref.watch(databaseProvider).watchMe());

final friendsProvider = StreamProvider<List<Profile>>(
    (ref) => ref.watch(databaseProvider).watchFriends());
