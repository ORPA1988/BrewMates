import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/providers.dart';
import '../../domain/badges.dart';
import '../../widgets/abzeichen_medaillon.dart';
import '../../widgets/trophaee.dart';

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
              const _Trophaeenband(),
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

/// Die Trophäen aus abgeschlossenen Challenges, quer scrollbar.
///
/// Bis 0.10.28 stand hier eine Reihe grauer `Chip`s mit Emoji und Titel —
/// vier verschiedene Auszeichnungen sahen darin identisch aus. Jetzt trägt
/// jede Trophäe ihr Metall (den Rang) und ihr Band samt Jahreszahl (das
/// Jahr).
///
/// Die Zeile fehlt ganz, solange es nichts zu zeigen gibt: Ein leerer
/// Abschnitt „Trophäen" wäre eine Aufforderung, keine Auskunft.
class _Trophaeenband extends ConsumerWidget {
  const _Trophaeenband();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final liste =
        ref.watch(meineAuszeichnungenProvider).valueOrNull ?? const [];
    if (liste.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            liste.length == 1 ? '1 Trophäe' : '${liste.length} Trophäen',
            style: theme.textTheme.titleMedium,
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: liste.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final a = liste[i];
              final woFuer = a.crewName == null
                  ? a.art.erklaerung
                  : '${a.art.erklaerung} · ${a.crewName}';
              return Semantics(
                // Ohne dies liest die Vorlesehilfe drei Bruchstücke
                // untereinander vor. Ein Satz sagt dasselbe in einem Zug.
                label: '${a.art.anzeige}, ${a.art.tier.anzeige}, für '
                    '${a.titel} ${a.jahr}. $woFuer.',
                excludeSemantics: true,
                child: SizedBox(
                  width: 104,
                  child: Column(
                    children: [
                      Trophaee(emoji: a.emoji, art: a.art, jahr: a.jahr),
                      const SizedBox(height: 6),
                      Text(
                        a.art.anzeige,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        a.titel,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
            AbzeichenMedaillon(
              emoji: def.emoji,
              tier: def.tier,
              anteil: progress.fraction,
              verdient: earned,
            ),
            const SizedBox(height: 8),
            Text(
              def.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: earned
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface,
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
                '${def.tier.anzeige} · ${timeAgo(progress.awardedAt!)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
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
