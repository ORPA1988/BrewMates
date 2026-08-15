import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/checkin_card.dart';

/// Durchsuchbares Bier-Tagebuch: alle eigenen Check-ins,
/// gruppiert nach Kalendertag.
///
/// Die Liste baut nur, was zu sehen ist, und lädt am Ende nach — ein
/// Tagebuch wächst ein Leben lang. Gesucht wird in der Abfrage, nicht im
/// bereits geladenen Fenster; sonst fände die Suche nur die letzten Seiten.
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(diarySearchProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    ref.read(diarySearchProvider.notifier).state = value;
    // Neue Suche beginnt wieder bei der ersten Seite.
    ref.read(diaryLimitProvider.notifier).state = feedPageSize;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diary = ref.watch(myDiaryProvider);
    final query = ref.watch(diarySearchProvider);
    final total = ref.watch(myCheckinCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Tagebuch')),
      body: diary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (loaded) {
          if (total == 0 && query.trim().isEmpty) return const _EmptyDiary();

          // Nach Kalendertag gruppieren und zu einer flachen Liste
          // ausrollen — nur so kann die Liste faul bauen.
          final rows = <_DiaryRow>[];
          DateTime? currentDay;
          for (final d in loaded) {
            final created = d.checkin.createdAt;
            final day = DateTime(created.year, created.month, created.day);
            if (currentDay == null || day != currentDay) {
              rows.add(_DayHeading(day));
              currentDay = day;
            }
            rows.add(_CheckinRow(d));
          }

          final limit = ref.watch(diaryLimitProvider);
          final maybeMore = loaded.length >= limit;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: rows.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _DiaryHeader(
                  controller: _searchController,
                  total: total,
                  query: query,
                  onChanged: _setQuery,
                  onClear: () {
                    _searchController.clear();
                    _setQuery('');
                  },
                );
              }
              final rowIndex = index - 1;
              if (rowIndex < rows.length) {
                final row = rows[rowIndex];
                if (row is _DayHeading) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      formatDate(row.day),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  );
                }
                return CheckinCard(
                  details: (row as _CheckinRow).details,
                  showAuthor: false,
                );
              }
              // Fußbereich: nachladen, Leermeldung oder Ruhe.
              if (loaded.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Keine Treffer für „${query.trim()}".',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (!maybeMore) return const SizedBox(height: 24);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final current = ref.read(diaryLimitProvider);
                if (current == limit) {
                  ref.read(diaryLimitProvider.notifier).state =
                      current + feedPageSize;
                }
              });
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            },
          );
        },
      ),
    );
  }
}

/// Kopfbereich: Gesamtzahl und Suchfeld.
class _DiaryHeader extends StatelessWidget {
  const _DiaryHeader({
    required this.controller,
    required this.total,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final int total;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '$total Check-ins',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Bier, Brauerei, Stil oder Notiz suchen …',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Suche löschen',
                    onPressed: onClear,
                  ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _EmptyDiary extends StatelessWidget {
  const _EmptyDiary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
}

/// Flache Zeile der Tagebuchliste: Tagesüberschrift oder Check-in.
sealed class _DiaryRow {
  const _DiaryRow();
}

class _DayHeading extends _DiaryRow {
  const _DayHeading(this.day);
  final DateTime day;
}

class _CheckinRow extends _DiaryRow {
  const _CheckinRow(this.details);
  final CheckinDetails details;
}
