import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/online/online_service.dart';
import '../../data/providers.dart';

/// Crew-Detail: Mitglieder, Einladungscode, Verlassen/Auflösen.
class CrewDetailScreen extends ConsumerWidget {
  const CrewDetailScreen({super.key, required this.crewId});

  final String crewId;

  Future<void> _leaveOrDelete(
      BuildContext context, WidgetRef ref, bool isOwner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isOwner ? 'Crew auflösen?' : 'Crew verlassen?'),
        content: Text(isOwner
            ? 'Die Crew wird für alle Mitglieder gelöscht.'
            : 'Du kannst später mit dem Einladungscode wieder beitreten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isOwner ? 'Auflösen' : 'Verlassen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    final error = isOwner
        ? await online.deleteCrew(crewId)
        : await online.leaveCrew(crewId);
    ref.invalidate(myCrewsProvider);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final crews = ref.watch(myCrewsProvider).valueOrNull ?? const [];
    RemoteCrew? crew;
    for (final c in crews) {
      if (c.id == crewId) crew = c;
    }
    final membersAsync = ref.watch(crewMembersProvider(crewId));
    final myUid = ref.watch(onlineUserProvider).valueOrNull?.id;
    final isOwner = crew != null && crew.ownerId == myUid;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              crew == null ? 'Crew' : '${crew.emoji} ${crew.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Einladung: Code = Crew-UUID (bewusst kein Kontakte-Import).
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Einladungscode', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(crewId,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Code kopieren'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: crewId));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Code kopiert – schick ihn '
                                  'deiner Runde 🍻')));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Mitglieder', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          membersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Fehler: $e'),
            data: (members) => members == null
                ? const Text('Mitglieder gerade nicht abrufbar (offline?).')
                : Column(
                    children: [
                      for (final m in members)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(m.profile.avatarEmoji,
                                style: const TextStyle(fontSize: 16)),
                          ),
                          title: Text(m.profile.displayName),
                          subtitle: Text('@${m.profile.username}'),
                          trailing: m.role == 'owner'
                              ? Chip(
                                  label: const Text('Gründer'),
                                  labelStyle: theme.textTheme.labelSmall,
                                  visualDensity: VisualDensity.compact,
                                )
                              : null,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            icon: Icon(
                isOwner ? Icons.delete_forever_outlined : Icons.logout,
                size: 18),
            label: Text(isOwner ? 'Crew auflösen' : 'Crew verlassen'),
            onPressed: () async => _leaveOrDelete(context, ref, isOwner),
          ),
          const SizedBox(height: 8),
          Text(
            'Startest du beim Zusammenkommen einen Crew-Beacon, sehen ihn '
            'nur Crew-Mitglieder — inklusive Standort und Check-ins der '
            'Runde.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
