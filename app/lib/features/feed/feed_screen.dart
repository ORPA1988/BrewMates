import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/badge_celebration.dart';
import '../../widgets/checkin_card.dart';

/// Startbildschirm: aktive Sessions der Freunde („Gerade unterwegs")
/// plus der Check-in-Feed.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final sessionsAsync = ref.watch(activeSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('BrewMates')),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (feed) {
          final sessions =
              sessionsAsync.valueOrNull ?? const <SessionDetails>[];
          if (feed.isEmpty && sessions.isEmpty) {
            return const _EmptyState();
          }
          return ListView(
            children: [
              if (sessions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Gerade unterwegs 🍻',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                SizedBox(
                  height: 150,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final s in sessions) _SessionCard(details: s),
                    ],
                  ),
                ),
                const Divider(),
              ],
              for (final details in feed) CheckinCard(details: details),
              // Platz für den schwebenden „Los!"-Button.
              const SizedBox(height: 88),
            ],
          );
        },
      ),
    );
  }
}

/// Kompakte Karte einer aktiven Session in der horizontalen Leiste.
class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.details});

  final SessionDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = details.session;
    final host = details.host;

    return SizedBox(
      width: 270,
      child: Card(
        child: InkWell(
          onTap: () => context.push('/session/${session.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      child: Text(host.avatarEmoji,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${host.displayName}'
                        '${session.venueName != null ? ' @ ${session.venueName}' : ''}',
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (session.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    session.message!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '⏱ noch ${remaining(session.expiresAt)}'
                  '${details.participants.isNotEmpty ? ' · 👥 ${details.participants.length}' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                if (host.isMe)
                  Text(
                    'Deine Session',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: () async {
                            await ref
                                .read(actionsProvider)
                                .toastSession(session.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Prost rübergeschickt 🍻')),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                          child: const Text('Prost! 🍻'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final earned = await ref
                                .read(actionsProvider)
                                .joinSession(session.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Du bist dabei!')),
                              );
                              await showBadgeCelebration(context, earned);
                            }
                          },
                          style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                          child: const Text('Bin dabei!'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Freundlicher Hinweis, wenn weder Sessions noch Check-ins vorhanden sind.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍻', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Noch ruhig hier. Starte eine Session oder check dein erstes Bier ein 🍻',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push('/session/start'),
              child: const Text('Session starten'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.push('/checkin'),
              child: const Text('Bier einchecken'),
            ),
          ],
        ),
      ),
    );
  }
}
