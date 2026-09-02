import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/badge_celebration.dart';
import '../../widgets/checkin_card.dart';
import '../../widgets/beacon_messages.dart';

/// „Der Abend": Live-Ansicht einer Session; beendete Sessions werden zum
/// Erinnerungs-Album (gleicher Screen, nur ohne Aktions-Buttons).
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  Future<void> _endSession(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final synced = await ref.read(actionsProvider).endMySession();
    if (!context.mounted) return;
    if (synced == false) messenger.showSnackBar(beaconEndFailedSnackBar);
    context.pop();
  }

  Future<void> _toast(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(actionsProvider).toastSession(sessionId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(ok ? toastSentSnackBar : reactionNotSentSnackBar);
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final ergebnis = await ref.read(actionsProvider).joinSession(sessionId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        ergebnis.synced ? joinedSnackBar : reactionNotSentSnackBar);
    if (ergebnis.earned.isNotEmpty && context.mounted) {
      await showBadgeCelebration(context, ergebnis.earned);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Uhr mitbeobachten, damit Restzeit und Aktiv-Status frisch bleiben.
    ref.watch(clockProvider);
    final details = ref.watch(sessionProvider(sessionId));

    return details.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Fehler: $e')),
      ),
      data: (d) {
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Session nicht gefunden')),
          );
        }
        final active = d.isActiveAt(DateTime.now());
        return Scaffold(
          appBar: AppBar(title: Text(d.session.venueName ?? 'Session')),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _HeaderCard(details: d, active: active),
              _ParticipantsRow(details: d),
              if (active) _ActionRow(details: d, screen: this),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text('Der Abend',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ..._timeline(context, ref),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _timeline(BuildContext context, WidgetRef ref) {
    final checkins = ref.watch(sessionCheckinsProvider(sessionId));
    return checkins.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) => [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Fehler: $e'),
        ),
      ],
      data: (list) {
        if (list.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Noch keine Check-ins in dieser Session.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ];
        }
        return [
          for (final c in list) CheckinCard(details: c, showAuthor: true),
        ];
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.details, required this.active});

  final SessionDetails details;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = details.session;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(details.host.avatarEmoji,
                    style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(details.host.displayName,
                          style: theme.textTheme.titleMedium),
                      Text('📍 ${session.venueName ?? 'unterwegs'}',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                Chip(
                  label: Text(active
                      ? '🟢 noch ${remaining(session.expiresAt)}'
                      : 'Beendet'),
                ),
              ],
            ),
            if (session.message != null) ...[
              const SizedBox(height: 8),
              Text(
                session.message!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Gestartet ${timeAgo(session.startedAt)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantsRow extends StatelessWidget {
  const _ParticipantsRow({required this.details});

  final SessionDetails details;

  @override
  Widget build(BuildContext context) {
    final people = [details.host, ...details.participants];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mit dabei', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in people)
                Chip(
                  avatar: Text(p.avatarEmoji),
                  label: Text(p.displayName),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.details, required this.screen});

  final SessionDetails details;
  final SessionDetailScreen screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMine = details.host.isMe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: isMine
            ? [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => screen._endSession(context, ref),
                    child: const Text('Session beenden'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push('/checkin'),
                    child: const Text('✅ Bier einchecken'),
                  ),
                ),
              ]
            : [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => screen._toast(context, ref),
                    child: const Text('Prost! 🍻'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => screen._join(context, ref),
                    child: const Text('Bin dabei!'),
                  ),
                ),
              ],
      ),
    );
  }
}
