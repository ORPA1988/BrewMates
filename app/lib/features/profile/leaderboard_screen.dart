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
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            // Kopfzeile + Einträge.
            itemCount: entries.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Punkte: 1 je Check-in · 5 je angelegtem Bier/Gasthaus · '
                    '2 je gepflegter Änderung',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                );
              }
              final rank = index - 1;
              final entry = entries[rank];
              return Card(
                color: entry.username == myUsername
                    ? scheme.primaryContainer
                    : null,
                child: ListTile(
                  leading: Text(
                    switch (rank) {
                      0 => '🥇',
                      1 => '🥈',
                      2 => '🥉',
                      _ => '${rank + 1}.',
                    },
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text('${entry.avatarEmoji} @${entry.username}'
                      '${entry.username == myUsername ? ' (du)' : ''}'),
                  trailing: Text('${entry.points} P.',
                      style: theme.textTheme.titleMedium),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
