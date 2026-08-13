import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';

/// Entdecken: Bier-Datenbank durchsuchen und filtern.
class BeersScreen extends ConsumerStatefulWidget {
  const BeersScreen({super.key});

  @override
  ConsumerState<BeersScreen> createState() => _BeersScreenState();
}

class _BeersScreenState extends ConsumerState<BeersScreen> {
  String _search = '';
  String? _style;
  bool _alcoholFreeOnly = false;
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final count =
          await ref.read(communitySyncProvider).syncFromGitHub();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Datenbank aktuell – $count Einträge geladen 🍺')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Kein Internet – lokale Datenbank bleibt gültig.')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = ref.watch(beerStylesProvider).valueOrNull ?? const <String>[];
    final beersAsync =
        ref.watch(beersProvider((search: _search, style: _style)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entdecken'),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Datenbank von GitHub aktualisieren',
            onPressed: _syncing ? null : _syncNow,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Bier hinzufügen',
            onPressed: () => context.push('/beers/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Bier, Brauerei oder Stil suchen …',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                ChoiceChip(
                  label: const Text('Alle'),
                  selected: _style == null,
                  onSelected: (_) => setState(() => _style = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('💧 Alkoholfrei'),
                  selected: _alcoholFreeOnly,
                  onSelected: (value) =>
                      setState(() => _alcoholFreeOnly = value),
                ),
                for (final style in styles) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(style),
                    selected: _style == style,
                    onSelected: (selected) =>
                        setState(() => _style = selected ? style : null),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: beersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Fehler: $error')),
              data: (beers) {
                final visible = _alcoholFreeOnly
                    ? beers.where((b) => b.beer.isAlcoholFree).toList()
                    : beers;
                if (visible.isEmpty) return const _EmptyResults();
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) =>
                      _BeerTile(item: visible[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BeerTile extends ConsumerWidget {
  const _BeerTile({required this.item});

  final BeerWithBrewery item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beer = item.beer;
    final brewery = item.brewery;
    final onWishlist = ref.watch(onWishlistProvider(beer.id)).valueOrNull ?? false;

    final fallbackEmoji = Text(
      beer.isAlcoholFree ? '💧' : '🍺',
      style: const TextStyle(fontSize: 28),
    );

    return Card(
      child: ListTile(
        leading: beer.imageUrl == null
            ? fallbackEmoji
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  beer.imageUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallbackEmoji,
                ),
              ),
        title: Text(beer.name),
        subtitle: Text(
          '${brewery.name}, ${brewery.country} · ${beer.style}'
          '${beer.abv != null ? ' · ${beer.abv} %' : ''}',
        ),
        trailing: IconButton(
          icon: Icon(onWishlist ? Icons.bookmark : Icons.bookmark_border),
          tooltip: onWishlist
              ? 'Von der Wunschliste entfernen'
              : 'Auf die Wunschliste',
          onPressed: () => ref.read(actionsProvider).toggleWishlist(beer.id),
        ),
        onTap: () => context.push('/beer/${beer.id}'),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              'Nichts gefunden. Fehlt ein Bier? '
              'In 30 Sekunden eingetragen:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/beers/add'),
              icon: const Icon(Icons.add),
              label: const Text('Bier hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}
