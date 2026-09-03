import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../widgets/beer_thumbnail.dart';

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
                leading: BeerThumbnail(
                  imageUrl: beer.imageUrl,
                  isAlcoholFree: beer.isAlcoholFree,
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
                        final messenger = ScaffoldMessenger.of(context);
                        final actions = ref.read(actionsProvider);
                        await actions.toggleWishlist(beer.id);
                        // „Rückgängig" ist hier wörtlich zu nehmen: Das
                        // Merken ist ein Umschalter, also legt derselbe
                        // Aufruf das Bier wieder zurück. Kein Zustand,
                        // den die Oberfläche zwischenlagern müsste.
                        messenger.showSnackBar(SnackBar(
                          content: Text('„${beer.name}" entfernt'),
                          duration: const Duration(seconds: 5),
                          action: SnackBarAction(
                            label: 'Rückgängig',
                            onPressed: () => actions.toggleWishlist(beer.id),
                          ),
                        ));
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
