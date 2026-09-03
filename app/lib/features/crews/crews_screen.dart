import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// 👥 Crews: feste Gruppen (Stammtisch, Verein, WG …) — der größte
/// Differenzierer gegenüber Beer With Me. Beitritt bewusst nur per
/// Einladungscode (Crew-UUID), kein Kontakte-Import.
class CrewsScreen extends ConsumerWidget {
  const CrewsScreen({super.key});

  static const _emojis = ['👥', '🍻', '🏒', '⚽', '🎳', '🎸', '🏔', '🔥'];

  Future<void> _createCrew(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    var emoji = _emojis.first;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Crew gründen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Name (z. B. Stammtisch Donnerstag)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final e in _emojis)
                    ChoiceChip(
                      label: Text(e),
                      selected: emoji == e,
                      onSelected: (_) => setState(() => emoji = e),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Gründen'),
            ),
          ],
        ),
      ),
    );
    if (created != true || nameController.text.trim().isEmpty) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    final (id, error) =
        await online.createCrew(nameController.text, emoji);
    ref.invalidate(myCrewsProvider);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Crew gegründet! Teile den Einladungscode 🍻')));
    if (id != null) unawaited(context.push('/crew/$id'));
  }

  Future<void> _joinCrew(BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crew beitreten'),
        content: TextField(
          controller: codeController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Einladungscode',
            hintText: 'Code von einem Crew-Mitglied einfügen',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Beitreten'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    final error = await online.joinCrew(codeController.text);
    ref.invalidate(myCrewsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Willkommen in der Crew! 🍻')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crewsAsync = ref.watch(myCrewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 Crews'),
        actions: [
          // Scannen steht vorn: Es ist der Weg, den man am Tisch nimmt.
          // Der getippte Code bleibt daneben — für Desktop, für die
          // Einladung per Nachricht und für alles, was keine Kamera hat.
          IconButton(
            tooltip: 'Crew-Code scannen',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/crews/scan'),
          ),
          IconButton(
            tooltip: 'Mit Code beitreten',
            icon: const Icon(Icons.key_outlined),
            onPressed: () async => _joinCrew(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async => _createCrew(context, ref),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Crew gründen'),
      ),
      body: crewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (crews) => crews.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👥', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'Noch keine Crew. Gründe deinen Stammtisch — '
                        'Crew-Beacons sieht nur die Crew.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final crew in crews)
                    Card(
                      child: ListTile(
                        leading: Text(crew.emoji,
                            style: const TextStyle(fontSize: 28)),
                        title: Text(crew.name),
                        subtitle: Text(crew.memberCount == 1
                            ? '1 Mitglied'
                            : '${crew.memberCount} Mitglieder'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/crew/${crew.id}'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
