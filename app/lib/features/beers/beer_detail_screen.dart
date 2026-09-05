import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/external_links.dart';
import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/story_sheet.dart';

/// Detailseite eines Biers: Infos, Bewertung, Einchecken, Wunschliste,
/// eigener Verlauf.
class BeerDetailScreen extends ConsumerWidget {
  const BeerDetailScreen({super.key, required this.beerId});

  final String beerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beerAsync = ref.watch(beerProvider(beerId));

    return beerAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Fehler: $error')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Bier nicht gefunden')),
          );
        }
        return _BeerDetailBody(item: item);
      },
    );
  }
}

class _BeerDetailBody extends ConsumerWidget {
  const _BeerDetailBody({required this.item});

  final BeerWithBrewery item;

  Future<void> _flagNotABeer(
      BuildContext context, WidgetRef ref, Beer beer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Als „kein Bier" melden?'),
        content: const Text(
            'Melde diesen Community-Eintrag, wenn hinter dem Barcode gar '
            'kein Bier steckt. Übersteigen die Meldungen die echten '
            'Check-ins deutlich, wird der Eintrag automatisch entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Melden'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null || !context.mounted) return;
    final barcode = beer.barcodes.split(',').first.trim();
    final counted = await online.flagBeerNotABeer(barcode);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(counted
          ? 'Danke, Meldung gezählt.'
          : 'Meldung nicht möglich (offline, schon gemeldet oder '
              'redaktioneller Eintrag).'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beer = item.beer;
    final brewery = item.brewery;
    final theme = Theme.of(context);
    final onWishlist = ref.watch(onWishlistProvider(beer.id)).valueOrNull ?? false;
    final myCheckins = (ref.watch(myDiaryProvider).valueOrNull ?? const [])
        .where((c) => c.beer.id == beer.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(beer.name),
        actions: [
          // Nutzererstellte Biere sind in-app bearbeitbar; redaktionelle
          // Community-Biere laufen über den GitHub-Korrektur-Vorschlag.
          if (beer.isUserSubmitted)
            IconButton(
              tooltip: 'Bearbeiten',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/beer/${beer.id}/edit'),
            )
          else
            IconButton(
              tooltip: 'Korrektur vorschlagen',
              icon: const Icon(Icons.rate_review_outlined),
              onPressed: () async => launchUrl(
                communityIssueUri(
                  subject: beer.name,
                  body: 'Bier: ${beer.name}\n'
                      'Brauerei: ${brewery.name}\n'
                      'Stil: ${beer.style} · ABV: ${beer.abv ?? '–'} %\n\n'
                      'Was stimmt nicht bzw. was fehlt?\n',
                ),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Kopf: Etikett-Foto (Open Food Facts), sonst Emoji
          if (beer.imageUrl != null) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  beer.imageUrl!,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    beer.isAlcoholFree ? '💧' : '🍺',
                    style: const TextStyle(fontSize: 56),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Herkunft des Bildes — pflichtgemäß und sichtbar.
            //
            // Bilder kommen aus zwei Quellen: Open Food Facts (CC-BY-SA)
            // und den Brauereien selbst. Ein fremdes Produktfoto ohne
            // Herkunftsangabe zu zeigen ist der Unterschied zwischen
            // Zitieren und Nehmen; `tools/validate_data.dart` lässt ein
            // Bild ohne Quelle deshalb gar nicht erst durch.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _bildHerkunft(beer),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ),
          ] else
            Text(
              beer.isAlcoholFree ? '💧' : '🍺',
              style: const TextStyle(fontSize: 56),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          Text(
            beer.name,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/brewery/${brewery.id}'),
              icon: const Text('🏭'),
              label: Text(
                '${brewery.name} · ${brewery.city}, ${brewery.country}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text(beer.style)),
              if (beer.abv != null) Chip(label: Text('${beer.abv} %')),
              if (beer.ibu != null) Chip(label: Text('IBU ${beer.ibu}')),
              if (beer.isAlcoholFree)
                const Chip(label: Text('💧 alkoholfrei')),
              if (beer.isUserSubmitted)
                const Chip(label: Text('👥 Community')),
            ],
          ),
          // Die Geschichte steht vor den Beschreibungen: Sie ist der
          // Grund, warum man auf der Seite bleibt.
          if (beer.story != null) ...[
            const SizedBox(height: 16),
            StorySection(story: beer.story, title: 'Die Geschichte dahinter'),
          ],
          if (beer.description != null) ...[
            const SizedBox(height: 16),
            Text('Laut Brauerei', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(beer.description!, style: theme.textTheme.bodyMedium),
          ],
          // „Erfahrungen aus der Community" hieß dieser Abschnitt bis
          // 0.10.15 — er ist aber keine: Der Text ist redaktionell
          // geschrieben, nicht von Nutzern. Ein Etikett, das eine
          // fremde Quelle behauptet, ist schlimmer als ein nüchternes.
          if (beer.descriptionCommunity != null) ...[
            const SizedBox(height: 12),
            Text('Redaktionelle Einschätzung',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(beer.descriptionCommunity!,
                style: theme.textTheme.bodyMedium),
          ],
          // Echte Community-Bewertung (aggregiert über alle Nutzer) hat
          // Vorrang; die redaktionelle Einschätzung bleibt als klar
          // gekennzeichneter Übergang sichtbar, solange sie existiert.
          ...switch (
              ref.watch(onlineRatingStatsProvider(beer.id)).valueOrNull) {
            (final avg, final count) => [
                const SizedBox(height: 12),
                Row(
                  children: [
                    RatingStars(rating: avg, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${avg.toStringAsFixed(2)} · $count echte '
                        'Community-Bewertung${count == 1 ? '' : 'en'} '
                        '(alle BrewMates)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            null => const <Widget>[],
          },
          // Hier stand bis 0.10.15 `communityRating` als Sternebild.
          // Es ist keins: Der Wert ist eine redaktionelle Schätzung
          // „auf Basis des allgemeinen Rufs" (DATENHERKUNFT.md), und er
          // lag bei fast allen Bieren zwischen 2,8 und 4,3 — als Sterne
          // ununterscheidbar. Ein Tester hat genau das gemeldet
          // (#143). Sterne behaupten eine Messung; was die Datenbank
          // wirklich hat, ist ein **Satz** über das Bier, und der steht
          // jetzt oben. Gemessene Sterne gibt es nur noch aus echten
          // Bewertungen (`onlineRatingStatsProvider`, darüber).
          //
          // Die Spalte bleibt in Daten und Schema: Der GitHub-Sync
          // schreibt sie weiter, und sie zu entfernen wäre eine
          // Migration ohne Gewinn.
          const SizedBox(height: 16),
          // Bewertungs-Card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ref.watch(beerStatsProvider(beer.id)).when(
                    loading: () => const SizedBox(
                      height: 24,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Text('Fehler: $error'),
                    data: (stats) {
                      if (stats.checkinCount == 0) {
                        return const Text(
                            'Noch keine Bewertungen – sei der Erste!');
                      }
                      return Row(
                        children: [
                          RatingStars(
                              rating: stats.avgRating ?? 0, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            '${stats.avgRating?.toStringAsFixed(2)} · '
                            '${stats.checkinCount} Check-ins',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      context.push('/checkin?beer=${beer.id}'),
                  child: const Text('✅ Einchecken'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(actionsProvider).toggleWishlist(beer.id),
                  child: Text(onWishlist
                      ? 'Auf der Wunschliste ✓'
                      : '+ Wunschliste'),
                ),
              ),
            ],
          ),
          // Community-Validierung: von Nutzern eingetragene Biere kann
          // jeder als „kein Bier" melden; übersteigen die Meldungen die
          // geloggten Check-ins um 10, entfernt der Server den Eintrag.
          if (beer.isUserSubmitted &&
              beer.barcodes.trim().isNotEmpty &&
              ref.watch(isSignedInProvider)) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Das ist kein Bier? Melden'),
                onPressed: () async => _flagNotABeer(context, ref, beer),
              ),
            ),
          ],
          if (myCheckins.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Dein Verlauf', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final details in myCheckins)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        timeAgo(details.checkin.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    RatingStars(rating: details.checkin.rating ?? 0),
                    const SizedBox(width: 8),
                    if (details.checkin.note != null)
                      Expanded(
                        child: Text(
                          details.checkin.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Beschriftung unter dem Produktbild.
///
/// Nennt die Brauerei-Quelle, wo das Bild von ihr stammt, und den
/// Nutzungshinweis, wo die Brauerei einen ausweist. Bei Open Food Facts
/// folgt die Herkunft aus der Lizenz.
String _bildHerkunft(Beer beer) {
  final quelle = beer.imageSource;
  if (quelle == null || quelle.isEmpty) {
    return 'Bild: Open Food Facts (CC-BY-SA)';
  }
  final host = Uri.tryParse(quelle)?.host.replaceFirst('www.', '') ?? quelle;
  final lizenz = beer.imageLicense;
  return lizenz == null || lizenz.isEmpty
      ? 'Bild: $host'
      : 'Bild: $host — $lizenz';
}
