import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/place_quick_sheet.dart';
import '../../widgets/venue_tile.dart';

/// Entdecken: Bier-Datenbank durchsuchen und filtern.
class BeersScreen extends ConsumerStatefulWidget {
  const BeersScreen({super.key});

  @override
  ConsumerState<BeersScreen> createState() => _BeersScreenState();
}

class _BeersScreenState extends ConsumerState<BeersScreen> {
  String _search = '';
  bool _cheapestFirst = false;
  String? _style;
  bool _alcoholFreeOnly = false;
  bool _syncing = false;

  /// Regions-Filter über das Land der Brauerei (null = alle).
  String? _country;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final count = await ref.read(communitySyncProvider).syncFromGitHub();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Datenbank aktuell – $count Einträge geladen 🍺')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kein Internet – lokale Datenbank bleibt gültig.')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles =
        ref.watch(beerStylesProvider).valueOrNull ?? const <String>[];
    final beersAsync =
        ref.watch(beersProvider((search: _search, style: _style)));
    // Brauerei-Treffer erscheinen nur bei aktiver Suche als eigene Sektion.
    // Gasthaus-Treffer nur bei aktiver Suche (sonst dominiert die Bierliste).
    final venueHits = _search.trim().length >= 2
        ? (ref.watch(venueSearchProvider(_search)).valueOrNull ??
            const <Venue>[])
        : const <Venue>[];
    final sortedVenues = [...venueHits];
    if (_cheapestFirst) {
      sortedVenues.sort((a, b) => (a.priceHalfL ?? double.infinity)
          .compareTo(b.priceHalfL ?? double.infinity));
    }
    final myUid = ref.watch(onlineUserProvider).valueOrNull?.id;
    final myLevel = ref.watch(accountLevelProvider).valueOrNull?.level ?? 0;
    final breweryHits = ref.watch(brewerySearchProvider(_search)).valueOrNull ??
        const <Brewery>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entdecken'),
        actions: [
          IconButton(
            tooltip: 'Alle Gasthäuser',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push('/venues'),
          ),
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Datenbank von GitHub aktualisieren',
            onPressed: _syncing ? null : _syncNow,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Bier hinzufügen',
            onPressed: () => context.push('/beers/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Bier, Brauerei oder Stil suchen …',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                ChoiceChip(
                  label: const Text('Alle'),
                  selected:
                      _style == null && _country == null && !_alcoholFreeOnly,
                  onSelected: (_) => setState(() {
                    _style = null;
                    _country = null;
                    _alcoholFreeOnly = false;
                  }),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('🇦🇹 Österreich'),
                  selected: _country == 'Österreich',
                  onSelected: (value) =>
                      setState(() => _country = value ? 'Österreich' : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('🇩🇪 Bayern'),
                  selected: _country == 'Deutschland',
                  onSelected: (value) =>
                      setState(() => _country = value ? 'Deutschland' : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('💧 Alkoholfrei'),
                  selected: _alcoholFreeOnly,
                  onSelected: (value) =>
                      setState(() => _alcoholFreeOnly = value),
                ),
                for (final style in styles) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(style),
                    selected: _style == style,
                    onSelected: (selected) =>
                        setState(() => _style = selected ? style : null),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: beersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Fehler: $error')),
              data: (beers) {
                var visible = _alcoholFreeOnly
                    ? beers.where((b) => b.beer.isAlcoholFree).toList()
                    : beers;
                if (_country != null) {
                  visible = visible
                      .where((b) => b.brewery.country == _country)
                      .toList();
                }
                if (visible.isEmpty &&
                    breweryHits.isEmpty &&
                    sortedVenues.isEmpty) {
                  return const _EmptyResults();
                }
                // Die drei Abschnitte zu einer flachen Zeilenliste
                // ausrollen: Nur so baut die Liste faul — sonst entstünden
                // bei jedem Tastendruck im Suchfeld alle Einträge neu.
                final rows = <Widget Function(BuildContext)>[];
                if (sortedVenues.isNotEmpty) {
                  rows.add((context) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  'Gasthäuser (${sortedVenues.length})',
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                            ),
                            // Preis-Radar: günstigstes 0,5 l zuerst.
                            FilterChip(
                              label: const Text('🍺 günstig zuerst'),
                              selected: _cheapestFirst,
                              onSelected: (v) =>
                                  setState(() => _cheapestFirst = v),
                            ),
                          ],
                        ),
                      ));
                  for (final venue in sortedVenues) {
                    rows.add((context) => VenueTile(
                          venue: venue,
                          canEdit: myUid != null &&
                              (venue.createdBy == myUid || myLevel >= 2),
                        ));
                  }
                }
                if (breweryHits.isNotEmpty) {
                  rows.add((context) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('Brauereien (${breweryHits.length})',
                            style: Theme.of(context).textTheme.titleSmall),
                      ));
                  for (final brewery in breweryHits) {
                    rows.add((context) => _BreweryTile(brewery: brewery));
                  }
                  if (visible.isNotEmpty) {
                    rows.add((context) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text('Biere (${visible.length})',
                              style: Theme.of(context).textTheme.titleSmall),
                        ));
                  }
                }
                for (final item in visible) {
                  rows.add((context) => _BeerTile(item: item));
                }

                // Pull-to-Refresh = Datenbank von GitHub aktualisieren
                // (gleiche Aktion wie der Sync-Knopf oben).
                return RefreshIndicator(
                  onRefresh: _syncNow,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: rows.length,
                    itemBuilder: (context, index) => rows[index](context),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BeerTile extends ConsumerWidget {
  const _BeerTile({required this.item});

  final BeerWithBrewery item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beer = item.beer;
    final brewery = item.brewery;
    final onWishlist =
        ref.watch(onWishlistProvider(beer.id)).valueOrNull ?? false;

    final fallbackEmoji = Text(
      beer.isAlcoholFree ? '💧' : '🍺',
      style: const TextStyle(fontSize: 28),
    );

    return Card(
      child: ListTile(
        leading: beer.imageUrl == null
            ? fallbackEmoji
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  beer.imageUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallbackEmoji,
                ),
              ),
        title: Text(beer.name),
        subtitle: Text(
          '${brewery.name}, ${brewery.country} · ${beer.style}'
          '${beer.abv != null ? ' · ${beer.abv} %' : ''}',
        ),
        trailing: IconButton(
          icon: Icon(onWishlist ? Icons.bookmark : Icons.bookmark_border),
          tooltip: onWishlist
              ? 'Von der Wunschliste entfernen'
              : 'Auf die Wunschliste',
          onPressed: () => ref.read(actionsProvider).toggleWishlist(beer.id),
        ),
        onTap: () => context.push('/beer/${beer.id}'),
      ),
    );
  }
}

class _BreweryTile extends StatelessWidget {
  const _BreweryTile({required this.brewery});

  final Brewery brewery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Text('🏭', style: TextStyle(fontSize: 26)),
        title: Text(brewery.name),
        subtitle: Text('${brewery.city}, ${brewery.country}'
            '${brewery.founded != null ? ' · seit ${brewery.founded}' : ''}'),
        trailing: IconButton(
          tooltip: 'Schnellansicht',
          icon: const Icon(Icons.map_outlined),
          onPressed: () async => showPlaceQuickSheet(
              context, PlaceQuickData.fromBrewery(brewery)),
        ),
        onTap: () => context.push('/brewery/${brewery.id}'),
      ),
    );
  }
}


class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              'Nichts gefunden. Fehlt ein Bier? '
              'In 30 Sekunden eingetragen:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/beers/add'),
              icon: const Icon(Icons.add),
              label: const Text('Bier hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}
