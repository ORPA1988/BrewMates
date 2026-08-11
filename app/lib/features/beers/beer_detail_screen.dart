import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/rating_stars.dart';

/// Detailseite eines Biers: Infos, Bewertung, Einchecken, Wunschliste,
/// eigener Verlauf.
class BeerDetailScreen extends ConsumerWidget {
  const BeerDetailScreen({super.key, required this.beerId});

  final String beerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beerAsync = ref.watch(beerProvider(beerId));

    return beerAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Fehler: $error')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Bier nicht gefunden')),
          );
        }
        return _BeerDetailBody(item: item);
      },
    );
  }
}

class _BeerDetailBody extends ConsumerWidget {
  const _BeerDetailBody({required this.item});

  final BeerWithBrewery item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beer = item.beer;
    final brewery = item.brewery;
    final theme = Theme.of(context);
    final onWishlist = ref.watch(onWishlistProvider(beer.id)).valueOrNull ?? false;
    final myCheckins = (ref.watch(myDiaryProvider).valueOrNull ?? const [])
        .where((c) => c.beer.id == beer.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(beer.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Kopf
          Text(
            beer.isAlcoholFree ? '💧' : '🍺',
            style: const TextStyle(fontSize: 56),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            beer.name,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/brewery/${brewery.id}'),
              icon: const Text('🏭'),
              label: Text(
                '${brewery.name} · ${brewery.city}, ${brewery.country}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text(beer.style)),
              if (beer.abv != null) Chip(label: Text('${beer.abv} %')),
              if (beer.ibu != null) Chip(label: Text('IBU ${beer.ibu}')),
              if (beer.isAlcoholFree)
                const Chip(label: Text('💧 alkoholfrei')),
              if (beer.isUserSubmitted)
                const Chip(label: Text('👥 Community')),
            ],
          ),
          if (beer.description != null) ...[
            const SizedBox(height: 16),
            Text('Laut Brauerei', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(beer.description!, style: theme.textTheme.bodyMedium),
          ],
          if (beer.descriptionCommunity != null) ...[
            const SizedBox(height: 12),
            Text('Erfahrungen aus der Community',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(beer.descriptionCommunity!,
                style: theme.textTheme.bodyMedium),
          ],
          if (beer.communityRating != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                RatingStars(rating: beer.communityRating!, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${beer.communityRating!.toStringAsFixed(1)} · '
                    'Community-Datenbank (redaktionelle Einschätzung)',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Bewertungs-Card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ref.watch(beerStatsProvider(beer.id)).when(
                    loading: () => const SizedBox(
                      height: 24,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Text('Fehler: $error'),
                    data: (stats) {
                      if (stats.checkinCount == 0) {
                        return const Text(
                            'Noch keine Bewertungen – sei der Erste!');
                      }
                      return Row(
                        children: [
                          RatingStars(
                              rating: stats.avgRating ?? 0, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            '${stats.avgRating?.toStringAsFixed(2)} · '
                            '${stats.checkinCount} Check-ins',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      context.push('/checkin?beer=${beer.id}'),
                  child: const Text('✅ Einchecken'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(actionsProvider).toggleWishlist(beer.id),
                  child: Text(onWishlist
                      ? 'Auf der Wunschliste ✓'
                      : '+ Wunschliste'),
                ),
              ),
            ],
          ),
          if (myCheckins.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Dein Verlauf', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final details in myCheckins)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        timeAgo(details.checkin.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    RatingStars(rating: details.checkin.rating ?? 0),
                    const SizedBox(width: 8),
                    if (details.checkin.note != null)
                      Expanded(
                        child: Text(
                          details.checkin.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
