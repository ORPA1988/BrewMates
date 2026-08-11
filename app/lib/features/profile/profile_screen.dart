import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/badges.dart';

const List<String> _avatarEmojis = [
  '🍺',
  '🍻',
  '🥨',
  '🧔',
  '👩',
  '🍀',
  '🔥',
  '🌊',
  '🦊',
  '🐻',
];

/// Profil: Kopf mit Avatar, Statistiken, Abzeichen-Vorschau,
/// Tagebuch, Wunschliste und Über-Sektion.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Profile me) async {
    final nameController = TextEditingController(text: me.displayName);
    final bioController = TextEditingController(text: me.bio ?? '');
    var selectedEmoji = me.avatarEmoji;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Profil bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final emoji in _avatarEmojis)
                      ChoiceChip(
                        label: Text(emoji),
                        selected: selectedEmoji == emoji,
                        onSelected: (_) =>
                            setState(() => selectedEmoji = emoji),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(actionsProvider).updateProfile(
                      displayName: nameController.text.trim(),
                      avatarEmoji: selectedEmoji,
                      bio: bioController.text.trim(),
                    );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    bioController.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final me = ref.watch(meProvider).valueOrNull;
    final stats = ref.watch(profileStatsProvider).valueOrNull;
    final badgeProgress = ref.watch(badgeProgressProvider).valueOrNull;
    final wishlistCount = ref.watch(wishlistProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ------------------------------------------------------------------
          // Kopf
          // ------------------------------------------------------------------
          if (me == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Row(
              children: [
                CircleAvatar(
                  radius: 44,
                  child: Text(me.avatarEmoji,
                      style: const TextStyle(fontSize: 40)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.displayName,
                          style: theme.textTheme.headlineSmall),
                      Text(
                        '@${me.username}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if ((me.bio ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(me.bio!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async => _showEditDialog(context, ref, me),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Profil bearbeiten',
                ),
              ],
            ),
          const SizedBox(height: 16),

          // ------------------------------------------------------------------
          // Statistik-Grid
          // ------------------------------------------------------------------
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.9,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _StatTile(label: 'Biere', value: stats?.uniqueBeers),
              _StatTile(label: 'Stile', value: stats?.uniqueStyles),
              _StatTile(label: 'Brauereien', value: stats?.uniqueBreweries),
              _StatTile(label: 'Länder', value: stats?.uniqueCountries),
              _StatTile(label: 'Venues', value: stats?.uniqueVenues),
              _StatTile(label: 'Check-ins', value: stats?.totalCheckins),
              _StatTile(label: 'Sessions', value: stats?.totalSessions),
              _StatTile(label: 'Abzeichen', value: stats?.badgeCount),
            ],
          ),
          const SizedBox(height: 16),

          // ------------------------------------------------------------------
          // Abzeichen-Vorschau
          // ------------------------------------------------------------------
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/profile/badges'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Abzeichen',
                              style: theme.textTheme.titleMedium),
                        ),
                        TextButton(
                          onPressed: () => context.push('/profile/badges'),
                          child: const Text('Alle ansehen'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _BadgePreviewRow(
                      earned: [
                        for (final p in badgeProgress ?? <BadgeProgress>[])
                          if (p.earned) p.def,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ------------------------------------------------------------------
          // Navigation
          // ------------------------------------------------------------------
          ListTile(
            leading: const Text('📖', style: TextStyle(fontSize: 24)),
            title: const Text('Tagebuch'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/diary'),
          ),
          ListTile(
            leading: const Text('⭐', style: TextStyle(fontSize: 24)),
            title: const Text('Wunschliste'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (wishlistCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$wishlistCount',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push('/profile/wishlist'),
          ),
          const SizedBox(height: 16),

          // ------------------------------------------------------------------
          // Über
          // ------------------------------------------------------------------
          Text('Über', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'BrewMates 1.0.0',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            '🔒 Alle Daten bleiben lokal auf deinem Gerät.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            'Karte: © OpenStreetMap',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value?.toString() ?? '–',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgePreviewRow extends StatelessWidget {
  const _BadgePreviewRow({required this.earned});

  final List<BadgeDef> earned;

  static const int _maxShown = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (earned.isEmpty) {
      return Text(
        'Noch keine Abzeichen – dein erster Check-in wartet!',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    final shown = earned.take(_maxShown).toList();
    final overflow = earned.length - shown.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in shown)
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primaryContainer,
            child: Text(badge.emoji, style: const TextStyle(fontSize: 18)),
          ),
        if (overflow > 0)
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.surfaceContainerHighest,
            child: Text(
              '+$overflow',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
