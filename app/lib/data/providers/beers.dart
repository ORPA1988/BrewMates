part of '../providers.dart';

// Biere, Wunschliste, Abzeichen, Statistiken
//
// Teil von `providers.dart` (Backlog B-4). Als `part`, nicht als
// eigene Bibliothek: Die Provider greifen auf gemeinsame private
// Helfer zu (`_now`, `_syncTickProvider`). Ein `part` teilt den
// Namensraum, ein Import nicht — sonst muessten interne Details
// oeffentlich werden, nur damit die Datei kleiner wird.

// ============================================================================
// Biere & Wunschliste
// ============================================================================

typedef BeerFilter = ({String search, String? style});

final beersProvider =
    StreamProvider.family<List<BeerWithBrewery>, BeerFilter>((ref, filter) =>
        ref
            .watch(databaseProvider)
            .watchBeers(search: filter.search, style: filter.style));

final beerStylesProvider =
    FutureProvider<List<String>>((ref) => ref.watch(databaseProvider).allStyles());

final beerProvider = StreamProvider.family<BeerWithBrewery?, String>(
    (ref, id) => ref.watch(databaseProvider).watchBeer(id));

final beerStatsProvider = StreamProvider.family<BeerStats, String>(
    (ref, id) => ref.watch(databaseProvider).watchBeerStats(id));

final breweryProvider = StreamProvider.family<Brewery?, String>(
    (ref, id) => ref.watch(databaseProvider).watchBrewery(id));

final breweryBeersProvider =
    StreamProvider.family<List<BeerWithBrewery>, String>((ref, id) =>
        ref.watch(databaseProvider).watchBeersOfBrewery(id));

final breweriesWithLocationProvider = StreamProvider<List<Brewery>>(
    (ref) => ref.watch(databaseProvider).watchBreweriesWithLocation());

/// Brauerei-Suche für den Entdecken-Tab (leer bei leerem Suchbegriff).
final brewerySearchProvider = StreamProvider.family<List<Brewery>, String>(
    (ref, search) => search.trim().isEmpty
        ? Stream.value(const <Brewery>[])
        : ref.watch(databaseProvider).watchBreweriesSearch(search.trim()));

final wishlistProvider = StreamProvider<List<BeerWithBrewery>>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchWishlist(me.id);
});

final onWishlistProvider = StreamProvider.family<bool, String>((ref, beerId) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(false);
  return ref.watch(databaseProvider).watchOnWishlist(me.id, beerId);
});

// ============================================================================
// Abzeichen & Statistiken
// ============================================================================

final myBadgesProvider = StreamProvider<List<UserBadge>>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchMyBadges(me.id);
});

/// Fortschritt aller Abzeichen; rechnet neu, wenn sich Tagebuch oder
/// verdiente Abzeichen ändern.
final badgeProgressProvider = FutureProvider<List<BadgeProgress>>((ref) async {
  final me = await ref.watch(meProvider.future);
  ref.watch(myDiaryProvider);
  ref.watch(myBadgesProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  return BadgeEngine(ref.watch(databaseProvider)).progressList(me.id,
      onlineUserId: online?.currentUser?.id);
});

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final me = await ref.watch(meProvider.future);
  ref.watch(myDiaryProvider);
  ref.watch(myBadgesProvider);
  return ref.watch(databaseProvider).computeProfileStats(me.id);
});
