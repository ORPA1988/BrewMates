import 'dart:async';

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

  /// Ablehnen mit Rückgängig-Frist.
  ///
  /// Der Serveraufruf wartet fünf Sekunden — er wird nicht rückgängig
  /// gemacht, sondern findet gar nicht erst statt. Warum das die einzige
  /// ehrliche Bauart ist, steht bei [AbgelehnteAnfragen]: Ein gelöschtes
  /// `friendships` wiederherstellen dürfte nur der Anfragende selbst.
  void _ablehnen() {
    final messenger = ScaffoldMessenger.of(context);
    final id = widget.request.friendshipId;
    final name = widget.request.from.displayName;
    final notifier = ref.read(abgelehnteAnfragenProvider.notifier);

    // Kein await: Die Karte verschwindet sofort aus der Liste, weil
    // `offeneAnfragenProvider` sie ab jetzt herausfiltert. Was danach
    // passiert, meldet die Snackbar.
    unawaited(notifier.ablehnen(id).then((ok) {
      if (ok == false) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Hat nicht geklappt — keine Verbindung? '
              'Die Anfrage ist weiterhin offen.'),
        ));
      }
    }));

    messenger.showSnackBar(SnackBar(
      content: Text('Anfrage von $name abgelehnt.'),
      duration: rueckgaengigFrist,
      action: SnackBarAction(
        label: 'Rückgängig',
        onPressed: () => notifier.zuruecknehmen(id),
      ),
    ));
  }

  Future<void> _annehmen() async {
    setState(() => _laeuft = true);
    final messenger = ScaffoldMessenger.of(context);
    final online = await ref.read(onlineServiceProvider.future);
    final ok = await online?.friends
            .respondRequest(widget.request.friendshipId, accept: true) ??
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
    messenger.showSnackBar(const SnackBar(
      content: Text('Ihr seid jetzt Freunde! 🍻'),
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
                  onPressed: _laeuft ? null : _ablehnen,
                  child: const Text('Ablehnen'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _laeuft ? null : _annehmen,
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
