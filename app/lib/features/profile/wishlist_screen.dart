import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// Wunschliste: vorgemerkte Biere, direkt eincheckbar oder entfernbar.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wishlist = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wunschliste')),
      body: wishlist.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '⭐ Noch leer. Bei jedem Bier findest du '
                      '„+ Wunschliste".',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/beers'),
                      child: const Text('Biere entdecken'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final beer = item.beer;
              return ListTile(
                leading: Text(
                  beer.isAlcoholFree ? '💧' : '🍺',
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(beer.name),
                subtitle: Text('${item.brewery.name} · ${beer.style}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Text('✅', style: TextStyle(fontSize: 18)),
                      tooltip: 'Jetzt einchecken',
                      onPressed: () =>
                          context.push('/checkin?beer=${beer.id}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Von der Wunschliste entfernen',
                      onPressed: () async {
                        await ref
                            .read(actionsProvider)
                            .toggleWishlist(beer.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Von der Wunschliste entfernt'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                onTap: () => context.push('/beer/${beer.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
