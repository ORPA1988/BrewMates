import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/online/online_service.dart' show CrewInvite, OnlineApi;
import '../../data/providers.dart';

/// 👥 Crews: feste Gruppen (Stammtisch, Verein, WG …) — der größte
/// Das Merkmal, das feste Runden von losen Freundeslisten trennt.
///
/// Drei Wege hinein, und der dritte unterscheidet sich grundsätzlich:
/// Code scannen und Code tippen entscheidet der Beitretende selbst; eine
/// **Einladung** (0044) entscheidet ein anderer und braucht deshalb eine
/// Antwort. Kein Kontakte-Import.
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
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Einladungscode',
            hintText: 'z. B. B3KM7Q',
            helperText: 'Sechs Zeichen — oder die lange Kennung',
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

    // Zwei Schreibweisen, ein Feld: der sechsstellige Code zum Vorlesen
    // (0041) und die lange Kennung, die es seit dem ersten Tag gibt.
    // Welche davon jemand einfügt, ist seine Sache — nicht seine
    // Entscheidung.
    final eingabe = codeController.text.trim();
    final error = OnlineApi.uuidPattern.hasMatch(eingabe)
        ? await online.joinCrew(eingabe)
        : await online.crews.joinByCode(eingabe) == null
            ? 'Diesen Einladungscode gibt es nicht.'
            : null;

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
        data: (crews) {
          final einladungen = ref.watch(crewInvitesProvider).valueOrNull ??
              const <CrewInvite>[];

          // Auch ohne eigene Crew kann eine Einladung warten — der
          // leere Zustand darf sie nicht verdecken.
          if (crews.isEmpty && einladungen.isEmpty) {
            return Center(
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
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Einladungen zuerst: Dort wartet jemand auf eine Antwort.
              for (final e in einladungen)
                _EinladungsKarte(einladung: e),
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
          );
        },
      ),
    );
  }
}

/// Eine wartende Einladung — annehmen oder ablehnen.
///
/// Steht ganz oben in der Liste, weil dort jemand auf eine Antwort
/// wartet. Dieselbe Haltung wie bei den Freundschaftsanfragen auf der
/// Startseite: Ein Mensch, der wartet, gehört nach vorn.
class _EinladungsKarte extends ConsumerStatefulWidget {
  const _EinladungsKarte({required this.einladung});

  final CrewInvite einladung;

  @override
  ConsumerState<_EinladungsKarte> createState() => _EinladungsKarteState();
}

class _EinladungsKarteState extends ConsumerState<_EinladungsKarte> {
  bool _laeuft = false;

  Future<void> _antworten({required bool annehmen}) async {
    setState(() => _laeuft = true);
    final messenger = ScaffoldMessenger.of(context);
    final online = await ref.read(onlineServiceProvider.future);
    final ok = online == null
        ? false
        : annehmen
            ? await online.crews.acceptInvite(widget.einladung.crewId)
            : await online.crews.declineInvite(widget.einladung.crewId);

    ref.invalidate(crewInvitesProvider);
    if (ok) ref.invalidate(myCrewsProvider);
    if (!mounted) return;
    setState(() => _laeuft = false);

    // Regel A-8: kein Erfolg, den der Server nicht bestätigt hat.
    messenger.showSnackBar(SnackBar(
      content: Text(!ok
          ? 'Hat nicht geklappt — keine Verbindung? Die Einladung steht '
              'weiterhin.'
          : annehmen
              ? 'Willkommen in der Crew! 🍻'
              : 'Einladung abgelehnt.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.einladung;

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(e.crewEmoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.crewName, style: theme.textTheme.titleSmall),
                      Text('${e.inviter.displayName} lädt dich ein',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Was der Beitritt bedeutet, steht dabei — nicht im Kleingedruckten.
            Text(
              'Als Mitglied siehst du die Runden der Crew — und sie deine, '
              'inklusive Standort während eines Crew-Beacons.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _laeuft ? null : () => _antworten(annehmen: false),
                  child: const Text('Ablehnen'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _laeuft ? null : () => _antworten(annehmen: true),
                  child: const Text('Beitreten'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
