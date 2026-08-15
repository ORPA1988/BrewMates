import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../domain/statistics.dart';
import 'stats_providers.dart';

/// Auswertung der eigenen Check-ins: Menge, Land, Stil, Gebinde, Verlauf.
///
/// Bewusst ein Rückblick, kein Wettbewerb — keine Rangliste gegen andere,
/// keine Zielvorgabe. Die Balken entstehen aus `Container`-Breiten statt
/// aus einer Diagramm-Bibliothek: Das spart ein Paket, das auf einer der
/// fünf Zielplattformen erfahrungsgemäß klemmt.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(statsProvider);
    final range = ref.watch(statsRangeProvider);
    final options = ref.watch(statsFilterOptionsProvider);
    final country = ref.watch(statsCountryProvider);
    final style = ref.watch(statsStyleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Zeitraum
          SegmentedButton<StatsRange>(
            segments: [
              for (final r in StatsRange.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {range},
            onSelectionChanged: (s) =>
                ref.read(statsRangeProvider.notifier).state = s.first,
          ),
          const SizedBox(height: 12),

          // Filter
          if (options.countries.length > 1 || options.styles.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (options.countries.length > 1)
                  _FilterMenu(
                    label: 'Land',
                    value: country,
                    options: options.countries,
                    onChanged: (v) =>
                        ref.read(statsCountryProvider.notifier).state = v,
                  ),
                if (options.styles.length > 1)
                  _FilterMenu(
                    label: 'Stil',
                    value: style,
                    options: options.styles,
                    onChanged: (v) =>
                        ref.read(statsStyleProvider.notifier).state = v,
                  ),
              ],
            ),
          const SizedBox(height: 16),

          if (stats.isEmpty)
            _EmptyStats(hasFilter: country != null || style != null)
          else ...[
            _Totals(stats: stats),
            const SizedBox(height: 24),
            _BarSection(title: 'Nach Land', slices: stats.byCountry),
            _BarSection(title: 'Nach Stil', slices: stats.byStyle),
            _BarSection(title: 'Nach Gebinde', slices: stats.byServing),
            _BarSection(title: 'Nach Brauerei', slices: stats.byBrewery),
            _BarSection(title: 'Check-ins je Monat', slices: stats.byMonth),
          ],
          const SizedBox(height: 24),
          Text(
            'Ausgewertet werden deine eigenen Check-ins. Die Zahlen sind '
            'ein Rückblick — kein Wettbewerb.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Auswahl „alle / einzelner Wert" für Land bzw. Stil.
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<String?>(value: null, child: Text('Alle ($label)')),
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Chip(
        label: Text(value ?? 'Alle ($label)'),
        avatar: const Icon(Icons.filter_list, size: 18),
      ),
    );
  }
}

/// Die Kopfzahlen.
class _Totals extends StatelessWidget {
  const _Totals({required this.stats});

  final CheckinStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatTile(
                value: '${stats.checkins}', label: 'Check-ins', emoji: '✅'),
            _StatTile(
                value: '${stats.distinctBeers}',
                label: 'verschiedene Biere',
                emoji: '🍺'),
            _StatTile(
                value: '${stats.distinctBreweries}',
                label: 'Brauereien',
                emoji: '🏭'),
            if (stats.distinctVenues > 0)
              _StatTile(
                  value: '${stats.distinctVenues}',
                  label: 'Orte',
                  emoji: '📍'),
            _StatTile(
                value: formatLitres(stats.totalLitres),
                label: 'Menge',
                emoji: '🍻'),
            if (stats.averageRating != null)
              _StatTile(
                  value: stats.averageRating!
                      .toStringAsFixed(2)
                      .replaceAll('.', ','),
                  label: 'Ø Bewertung',
                  emoji: '⭐'),
            if (stats.alcoholFree > 0)
              _StatTile(
                  value: '${stats.alcoholFree}',
                  label: 'alkoholfrei',
                  emoji: '💧'),
          ],
        ),
        if (stats.volumeIsRough) ...[
          const SizedBox(height: 8),
          Text(
            // Eine Literzahl, die so tut, als wäre sie gemessen, wäre eine
            // Lüge — deshalb steht hier, wie viel geschätzt ist.
            'Bei ${stats.estimatedCount} von ${stats.checkins} Check-ins '
            'fehlt die Füllmenge — dort ist nach Gebinde geschätzt.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.value, required this.label, required this.emoji});

  final String value;
  final String label;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Eine Aufteilung als Balkenreihe. Ohne Diagramm-Bibliothek — die
/// Balkenbreite ist ein Anteil der verfügbaren Breite.
class _BarSection extends StatelessWidget {
  const _BarSection({required this.title, required this.slices});

  final String title;
  final List<StatSlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final max = slices.map((s) => s.count).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final s in slices)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      s.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 16,
                          // Mindestbreite, damit auch der kleinste Wert
                          // sichtbar bleibt.
                          width: (constraints.maxWidth * s.count / max)
                              .clamp(4.0, constraints.maxWidth),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text('${s.count}',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Text('📊', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            hasFilter
                ? 'Für diese Auswahl gibt es noch nichts. Nimm einen Filter '
                    'heraus oder wähle einen größeren Zeitraum.'
                : 'Noch nichts auszuwerten — dein erster Check-in fehlt.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          if (!hasFilter) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/scan'),
              child: const Text('🍺 Bier scannen'),
            ),
          ],
        ],
      ),
    );
  }
}
