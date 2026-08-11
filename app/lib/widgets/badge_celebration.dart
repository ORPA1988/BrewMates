import 'package:flutter/material.dart';

import '../domain/badges.dart';

/// Zeigt einen Gratulations-Dialog für neu verdiente Abzeichen.
/// Bei leerer Liste passiert nichts.
Future<void> showBadgeCelebration(
    BuildContext context, List<BadgeDef> badges) async {
  if (badges.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      return AlertDialog(
        title: Text(
          badges.length == 1 ? 'Neues Abzeichen! 🎉' : 'Neue Abzeichen! 🎉',
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final badge in badges) ...[
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(badge.emoji,
                      style: const TextStyle(fontSize: 56)),
                ),
                const SizedBox(height: 12),
                Text(
                  badge.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  badge.description,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (badge != badges.last) const SizedBox(height: 24),
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
