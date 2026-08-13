import 'package:flutter/material.dart';

import '../domain/badges.dart';
import '../domain/challenges.dart';

/// Gemeinsames Anzeigemodell für Feier-Dialoge: Abzeichen, abgeschlossene
/// Challenges und (später) Level-Aufstiege sehen für den Dialog gleich aus.
class CelebrationItem {
  const CelebrationItem({
    required this.emoji,
    required this.name,
    required this.description,
    this.headline,
  });

  factory CelebrationItem.fromBadge(BadgeDef badge) => CelebrationItem(
        emoji: badge.emoji,
        name: badge.name,
        description: badge.description,
      );

  factory CelebrationItem.fromChallenge(ChallengeDef def) => CelebrationItem(
        emoji: def.emoji,
        name: def.title,
        description: 'Challenge geschafft! ${def.description}'.trim(),
        headline: 'Challenge gemeistert! 🏆',
      );

  final String emoji;
  final String name;
  final String description;

  /// Optionale eigene Dialog-Überschrift (erste gewinnt).
  final String? headline;
}

/// Zeigt einen Gratulations-Dialog für neu verdiente Abzeichen.
/// Bei leerer Liste passiert nichts.
Future<void> showBadgeCelebration(
        BuildContext context, List<BadgeDef> badges) =>
    showCelebration(
        context, [for (final b in badges) CelebrationItem.fromBadge(b)]);

/// Gratulations-Dialog für beliebige Errungenschaften.
Future<void> showCelebration(
    BuildContext context, List<CelebrationItem> items) async {
  if (items.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      String? custom;
      for (final item in items) {
        if (item.headline != null) {
          custom = item.headline;
          break;
        }
      }
      final headline = custom ??
          (items.length == 1 ? 'Neues Abzeichen! 🎉' : 'Neue Abzeichen! 🎉');
      return AlertDialog(
        title: Text(headline, textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items) ...[
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Text(item.emoji, style: const TextStyle(fontSize: 56)),
                ),
                const SizedBox(height: 12),
                Text(
                  item.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (item != items.last) const SizedBox(height: 24),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Prost! 🍻'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      );
    },
  );
}
