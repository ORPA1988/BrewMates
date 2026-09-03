import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/providers.dart';
import 'beer_thumbnail.dart';

/// Ein vorhandenes Bier aus der Datenbank auswählen.
///
/// Gedacht für den Fall „unbekannter Barcode": Meistens ist das Bier
/// längst erfasst und hat nur diese eine EAN noch nicht. Eine EAN
/// bezeichnet die **Handelseinheit** — 0,33-Flasche, 0,5-Dose und Sixpack
/// tragen je eigene Nummern —, deshalb hat ein Bier mehrere davon und
/// bekommt hier eine dazu, statt als Duplikat neu zu entstehen.
///
/// Liegt in `widgets/`, weil der Anlege-Bildschirm es öffnet und Features
/// einander nicht importieren dürfen (Vorbild: `venue_picker.dart`).
Future<BeerWithBrewery?> showBeerPicker(BuildContext context) =>
    showModalBottomSheet<BeerWithBrewery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: const _BeerPicker(),
      ),
    );

class _BeerPicker extends ConsumerStatefulWidget {
  const _BeerPicker();

  @override
  ConsumerState<_BeerPicker> createState() => _BeerPickerState();
}

class _BeerPickerState extends ConsumerState<_BeerPicker> {
  String _suche = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final treffer =
        ref.watch(beersProvider((search: _suche, style: null))).valueOrNull ??
            const <BeerWithBrewery>[];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vorhandenes Bier suchen',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Ist das Bier schon da und hat nur diesen Barcode noch '
                  'nicht, ergänze ihn hier — statt einen zweiten Eintrag '
                  'anzulegen.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Marke oder Brauerei',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _suche = v),
                ),
              ],
            ),
          ),
          if (_suche.trim().length < 2)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Mindestens zwei Zeichen eingeben.'),
            )
          else if (treffer.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nichts gefunden — dann ist es wirklich neu.'),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: treffer.length,
                itemBuilder: (_, i) {
                  final t = treffer[i];
                  return ListTile(
                    leading: BeerThumbnail(
                      imageUrl: t.beer.imageUrl,
                      isAlcoholFree: t.beer.isAlcoholFree,
                    ),
                    title: Text(t.beer.name),
                    subtitle: Text('${t.brewery.name} · ${t.beer.style}'),
                    onTap: () => Navigator.pop(context, t),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
