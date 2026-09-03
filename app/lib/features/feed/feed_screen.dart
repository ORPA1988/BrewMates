import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../widgets/paged_checkin_list.dart';

/// Feed: der chronologische Check-in-Strom aller Freunde.
/// (Aktive Sessions leben prominent auf dem Home-Tab.)
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            tooltip: 'Statistik',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/profile/stats'),
          ),
        ],
      ),
      // Nach unten ziehen holt neu. Das fehlte ausgerechnet hier — auf
      // dem einen Bildschirm, bei dem man wissen will, ob gerade jemand
      // etwas getrunken hat. Realtime liefert zwar von selbst, aber wer
      // das nicht weiß, zieht; und wenn nichts passiert, glaubt er, es
      // gebe nichts Neues.
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(remoteFeedProvider);
          ref.invalidate(feedReactionsProvider);
          // Auf die Antwort warten, sonst verschwindet der Kringel,
          // bevor irgendetwas geladen ist — das sieht aus wie „nichts
          // Neues", auch wenn gerade nachgeladen wird.
          await ref.read(remoteFeedProvider.future);
        },
        child: feedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
          data: (feed) {
            if (feed.isEmpty) return const _EmptyState();
            return PagedCheckinList(
              items: feed,
              limitProvider: feedLimitProvider,
            );
          },
        ),
      ),
    );
  }
}

/// Freundlicher Hinweis, wenn noch keine Check-ins vorhanden sind.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // Als scrollbare Liste, obwohl nichts zu scrollen ist: Sonst nimmt
    // der leere Feed die Ziehgeste nicht an — und gerade dort will man
    // sie („ist wirklich nichts da?").
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🍻', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'Noch ruhig hier. Scanne dein erstes Bier oder starte einen '
                'Beacon 🍻',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/scan'),
                child: const Text('🍺 Bier scannen'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.push('/beacon'),
                child: const Text('🍻 Zusammenkommen!'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
