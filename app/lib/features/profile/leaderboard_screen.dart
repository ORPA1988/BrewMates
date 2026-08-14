import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// 🏅 Datenpflege-Bestenliste: wer trägt am meisten zur gemeinsamen
/// Datenbank bei? (Punkteformel der Vertrauensstufen; private Profile
/// erscheinen nicht.)
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entriesAsync = ref.watch(leaderboardProvider);
    final myUsername =
        ref.watch(myRemoteProfileProvider).valueOrNull?.username;

    return Scaffold(
      appBar: AppBar(title: const Text('🏅 Datenpflege-Bestenliste')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Fehler: $error')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Einträge – Check-ins, neue Biere und '
                  'gepflegte Gasthäuser bringen Punkte! 🍻',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Punkte: 1 je Check-in · 5 je angelegtem Bier/Gasthaus · '
                '2 je gepflegter Änderung',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              for (final (index, entry) in entries.indexed)
                Card(
                  color: entry.username == myUsername
                      ? scheme.primaryContainer
                      : null,
                  child: ListTile(
                    leading: Text(
                      switch (index) {
                        0 => '🥇',
                        1 => '🥈',
                        2 => '🥉',
                        _ => '${index + 1}.',
                      },
                      style: const TextStyle(fontSize: 20),
                    ),
                    title: Text(
                        '${entry.avatarEmoji} @${entry.username}'
                        '${entry.username == myUsername ? ' (du)' : ''}'),
                    trailing: Text('${entry.points} P.',
                        style: theme.textTheme.titleMedium),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
