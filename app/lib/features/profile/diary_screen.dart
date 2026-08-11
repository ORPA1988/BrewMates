import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/checkin_card.dart';

/// Durchsuchbares Bier-Tagebuch: alle eigenen Check-ins,
/// gruppiert nach Kalendertag.
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(CheckinDetails d) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return d.beer.name.toLowerCase().contains(q) ||
        d.brewery.name.toLowerCase().contains(q) ||
        (d.checkin.note ?? '').toLowerCase().contains(q) ||
        d.beer.style.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diary = ref.watch(myDiaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tagebuch')),
      body: diary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (all) {
          if (all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Dein Tagebuch ist noch leer. '
                      'Zeit für den ersten Schluck! 🍺',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/checkin'),
                      child: const Text('✅ Bier einchecken'),
                    ),
                  ],
                ),
              ),
            );
          }

          final filtered = all.where(_matches).toList();

          // Nach Kalendertag gruppieren (bereits absteigend sortiert).
          final groups = <DateTime, List<CheckinDetails>>{};
          for (final d in filtered) {
            final created = d.checkin.createdAt;
            final day =
                DateTime(created.year, created.month, created.day);
            groups.putIfAbsent(day, () => []).add(d);
          }
          final days = groups.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${all.length} Check-ins',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Bier, Brauerei, Stil oder Notiz suchen …',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Suche löschen',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Keine Treffer für „${_query.trim()}".',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final day in days) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    formatDate(day),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                for (final d in groups[day]!)
                  CheckinCard(details: d, showAuthor: false),
              ],
            ],
          );
        },
      ),
    );
  }
}
