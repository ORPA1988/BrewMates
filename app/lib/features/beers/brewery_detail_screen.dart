import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/external_links.dart';
import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import 'story_sheet.dart';

/// Brauerei-Detailseite: Standort, Eigentümer, Kennzahlen und alle Biere
/// der Brauerei aus der Community-Datenbank.
class BreweryDetailScreen extends ConsumerWidget {
  const BreweryDetailScreen({super.key, required this.breweryId});

  final String breweryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breweryAsync = ref.watch(breweryProvider(breweryId));

    return Scaffold(
      appBar: AppBar(title: const Text('Brauerei')),
      body: breweryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (brewery) {
          if (brewery == null) {
            return const Center(child: Text('Brauerei nicht gefunden.'));
          }
          return _BreweryDetails(brewery: brewery);
        },
      ),
    );
  }
}

class _BreweryDetails extends ConsumerWidget {
  const _BreweryDetails({required this.brewery});

  final Brewery brewery;

  String _formatNumber(int value) =>
      NumberFormat.decimalPattern('de').format(value);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final beers = ref.watch(breweryBeersProvider(brewery.id)).valueOrNull ??
        const <BeerWithBrewery>[];

    final facts = <(IconData, String, String)>[
      if (brewery.address != null)
        (Icons.place_outlined, 'Adresse', brewery.address!),
      if (brewery.founded != null)
        (Icons.history, 'Gegründet', '${brewery.founded}'),
      if (brewery.ownership != null)
        (Icons.account_balance_outlined, 'Eigentümer', brewery.ownership!),
      if (brewery.employees != null)
        (Icons.groups_outlined, 'Mitarbeitende',
            'ca. ${_formatNumber(brewery.employees!)}'),
      if (brewery.annualOutputHl != null)
        (Icons.water_drop_outlined, 'Jahresausstoß',
            'ca. ${_formatNumber(brewery.annualOutputHl!)} hl'),
      if (brewery.revenueEur != null)
        (Icons.payments_outlined, 'Umsatz',
            'ca. ${_formatNumber(brewery.revenueEur!)} €'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text('🏭', style: TextStyle(fontSize: 44)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brewery.name, style: theme.textTheme.headlineSmall),
                  Text('${brewery.city}, ${brewery.country}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (facts.isNotEmpty)
          Card(
            child: Column(
              children: [
                for (final (icon, label, value) in facts)
                  ListTile(
                    dense: true,
                    leading: Icon(icon),
                    title: Text(label),
                    subtitle: Text(value),
                  ),
              ],
            ),
          ),
        if (brewery.website != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(brewery.website!),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(brewery.website!
                .replaceFirst(RegExp('^https?://(www\\.)?'), '')),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => launchUrl(
            googleMapsSearchUri(
              lat: brewery.latitude,
              lng: brewery.latitude == null ? null : brewery.longitude,
              query: '${brewery.name}, ${brewery.city}',
            ),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('In Google Maps öffnen'),
        ),
        if (brewery.story != null) ...[
          const SizedBox(height: 12),
          StorySection(
              story: brewery.story, title: 'Die Geschichte der Brauerei'),
        ],
        if (brewery.notes != null) ...[
          const SizedBox(height: 12),
          Text('Über die Brauerei', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(brewery.notes!),
        ],
        if (brewery.dataStatus != null) ...[
          const SizedBox(height: 8),
          Text(
            'ℹ️ ${brewery.dataStatus!}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        // Redaktionelle Community-Brauereien sind in-app read-only –
        // Korrekturen laufen über die GitHub-Pipeline; selbst angelegte
        // (UUID) sind direkt bearbeitbar.
        if (isUuid(brewery.id))
          OutlinedButton.icon(
            onPressed: () => context.push('/brewery/${brewery.id}/edit'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Bearbeiten (nur auf deinem Gerät)'),
          )
        else
          OutlinedButton.icon(
            onPressed: () async => launchUrl(
              communityIssueUri(
                subject: brewery.name,
                body: 'Brauerei: ${brewery.name} (${brewery.city}, '
                    '${brewery.country})\n\n'
                    'Was stimmt nicht bzw. was fehlt?\n',
              ),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Korrektur vorschlagen'),
          ),
        const SizedBox(height: 16),
        Text('Biere (${beers.length})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final item in beers)
          Card(
            child: ListTile(
              leading: Text(item.beer.isAlcoholFree ? '💧' : '🍺',
                  style: const TextStyle(fontSize: 26)),
              title: Text(item.beer.name),
              subtitle: Text('${item.beer.style}'
                  '${item.beer.abv != null ? ' · ${item.beer.abv} %' : ''}'),
              trailing: item.beer.communityRating != null
                  ? Chip(
                      label: Text(
                          '⭐ ${item.beer.communityRating!.toStringAsFixed(1)}'),
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
              onTap: () => context.push('/beer/${item.beer.id}'),
            ),
          ),
        if (beers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Noch keine Biere dieser Brauerei in der Datenbank.'),
          ),
      ],
    );
  }
}
