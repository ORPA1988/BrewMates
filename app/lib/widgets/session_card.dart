import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/db/database.dart';
import '../data/providers.dart';
import 'badge_celebration.dart';

/// Kompakte Karte einer aktiven Session („Gerade unterwegs"-Leiste,
/// genutzt auf Home und überall, wo Sessions beworben werden).
class SessionCard extends ConsumerWidget {
  const SessionCard({super.key, required this.details});

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
                        '${host.displayName} @ '
                        '${session.venueName ?? 'unterwegs'}',
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
