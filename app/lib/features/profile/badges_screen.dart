import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/providers.dart';
import '../../domain/badges.dart';

/// Grafische Abzeichen-Galerie mit Fortschritt.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(badgeProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Abzeichen')),
      body: progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (list) {
          final earnedCount = list.where((p) => p.earned).length;
          final total = list.length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$earnedCount von $total verdient',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: total == 0 ? 0 : earnedCount / total,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount:
                      MediaQuery.sizeOf(context).width >= 800 ? 4 : 2,
                  childAspectRatio: 0.95,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final p in list) _BadgeCard(progress: p),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.progress});

  final BadgeProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final def = progress.def;
    final earned = progress.earned;

    return Card(
      color: earned ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: earned
                    ? scheme.surface
                    : scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Opacity(
                opacity: earned ? 1.0 : 0.35,
                child:
                    Text(def.emoji, style: const TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              def.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: earned
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              def.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: earned
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            if (earned)
              Text(
                'Verdient · ${timeAgo(progress.awardedAt!)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onPrimaryContainer),
              )
            else ...[
              LinearProgressIndicator(value: progress.fraction),
              const SizedBox(height: 4),
              Text(
                '${progress.progress} / ${def.target}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
