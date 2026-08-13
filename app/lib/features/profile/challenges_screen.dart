import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/challenges.dart';

/// Aktive Herausforderungen mit Fortschritt; abgeschlossene behalten ihr
/// Häkchen. Tap zeigt Details samt „Geschafft von"-Liste (Freunde).
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  static String remainingLabel(DateTime endsAt, DateTime now) {
    final left = endsAt.difference(now);
    if (left.isNegative) return 'beendet';
    if (left.inDays >= 1) {
      return 'noch ${left.inDays} Tag${left.inDays == 1 ? '' : 'e'}';
    }
    if (left.inHours >= 1) return 'noch ${left.inHours} Std.';
    return 'endet gleich!';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(challengeProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🏆 Challenges')),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Fehler: $error')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'Gerade läuft keine Challenge.\nSchau bald wieder vorbei!',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(challengesProvider);
              await ref.read(challengeProgressProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in items)
                  _ChallengeCard(
                      item: item, key: ValueKey(item.def.id)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({super.key, required this.item});

  final ChallengeProgress item;

  Future<void> _showDetails(BuildContext context, WidgetRef ref) async {
    final online = await ref.read(onlineServiceProvider.future);
    final finishers = online == null
        ? const []
        : await online.challengeCompletions(item.def.id);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.def.emoji} ${item.def.title}',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (item.def.description.isNotEmpty)
                  Text(item.def.description,
                      style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text(
                  'Dein Stand: ${item.progress} von ${item.def.target}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Text('Geschafft von', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                if (finishers.isEmpty)
                  Text('Noch niemand – sei du die/der Erste! 🍻',
                      style: theme.textTheme.bodyMedium)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final p in finishers)
                        Chip(
                            label: Text(
                                '${p.avatarEmoji} @${p.username}')),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final def = item.def;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async => _showDetails(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(def.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(def.title, style: theme.textTheme.titleMedium),
                        Text(
                          ChallengesScreen.remainingLabel(
                              def.endsAt, DateTime.now()),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (item.completed)
                    Icon(Icons.check_circle, color: scheme.primary, size: 28),
                ],
              ),
              if (def.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(def.description, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.fraction,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${item.progress}/${def.target}',
                      style: theme.textTheme.labelLarge),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
