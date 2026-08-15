import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/online/online_service.dart';
import '../data/providers.dart';

/// „Später" — Anfragen, die auf der Startseite gerade nicht stören sollen.
///
/// Bewusst nur für diese Sitzung und bewusst **nur für die Startseite**:
/// Im Freunde-Bildschirm bleibt jede Anfrage sichtbar. „Später" heißt
/// „nicht jetzt", nicht „weg" — eine Anfrage still verschwinden zu lassen
/// wäre die schlechteste der drei Antworten.
final anfrageSpaeterProvider = StateProvider<Set<String>>((ref) => {});

/// Eine offene Freundschaftsanfrage mit den drei möglichen Antworten.
///
/// Liegt in `widgets/`, weil Startseite und Freunde-Bildschirm sie beide
/// zeigen und Features einander nicht importieren dürfen.
class FriendRequestCard extends ConsumerStatefulWidget {
  const FriendRequestCard({
    super.key,
    required this.request,
    this.zeigeSpaeter = false,
  });

  final FriendRequest request;

  /// „Später" gibt es nur dort, wo die Anfrage ungefragt erscheint — also
  /// auf der Startseite. Wer den Freunde-Bildschirm öffnet, hat sie
  /// bereits gesucht.
  final bool zeigeSpaeter;

  @override
  ConsumerState<FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends ConsumerState<FriendRequestCard> {
  bool _laeuft = false;

  Future<void> _antworten({required bool annehmen}) async {
    setState(() => _laeuft = true);
    final messenger = ScaffoldMessenger.of(context);
    final online = await ref.read(onlineServiceProvider.future);
    final ok = await online?.friends
            .respondRequest(widget.request.friendshipId, accept: annehmen) ??
        false;
    if (!mounted) return;
    setState(() => _laeuft = false);

    if (!ok) {
      // Aus A-8: Ein fehlgeschlagener Aufruf darf nicht als Erfolg
      // aussehen. Die Liste bleibt auf dem Stand des Servers stehen.
      messenger.showSnackBar(const SnackBar(
        content: Text('Hat nicht geklappt — keine Verbindung? '
            'Die Anfrage ist weiterhin offen.'),
      ));
      return;
    }
    ref.invalidate(friendRequestsProvider);
    ref.invalidate(onlineFriendsProvider);
    messenger.showSnackBar(SnackBar(
      content: Text(annehmen
          ? 'Ihr seid jetzt Freunde! 🍻'
          : 'Anfrage abgelehnt.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final von = widget.request.from;

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(von.avatarEmoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(von.displayName,
                          style: theme.textTheme.titleSmall),
                      Text('@${von.username} möchte dein BrewMate sein',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.zeigeSpaeter)
                  TextButton(
                    onPressed: _laeuft
                        ? null
                        : () => ref
                            .read(anfrageSpaeterProvider.notifier)
                            .update((s) =>
                                {...s, widget.request.friendshipId}),
                    child: const Text('Später'),
                  ),
                TextButton(
                  onPressed:
                      _laeuft ? null : () => _antworten(annehmen: false),
                  child: const Text('Ablehnen'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed:
                      _laeuft ? null : () => _antworten(annehmen: true),
                  child: const Text('Annehmen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
