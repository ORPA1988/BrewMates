import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../widgets/checkin_card.dart';

/// Feed: der chronologische Check-in-Strom aller Freunde.
/// (Aktive Sessions leben prominent auf dem Home-Tab.)
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (feed) {
          if (feed.isEmpty) return const _EmptyState();
          return ListView(
            children: [
              for (final details in feed) CheckinCard(details: details),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

/// Freundlicher Hinweis, wenn noch keine Check-ins vorhanden sind.
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
    );
  }
}
