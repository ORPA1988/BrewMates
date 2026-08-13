import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/db/database.dart';
import '../data/providers.dart';
import '../data/venue_sync.dart';

/// Ergebnis der Gasthaus-Auswahl: entweder ein Eintrag aus der gemeinsamen
/// Datenbank (venueId gesetzt) oder Freitext wie bisher (venueId null).
typedef VenueSelection = ({String? venueId, String venueName});

/// Bottom-Sheet: Gasthaus aus der gemeinsamen DB suchen, Freitext als
/// Fallback, oder direkt ein neues Gasthaus anlegen. Funktioniert komplett
/// aus dem lokalen Cache (offlinefähig).
Future<VenueSelection?> showVenuePicker(BuildContext context,
    {String? initialQuery}) {
  return showModalBottomSheet<VenueSelection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: _VenuePickerSheet(initialQuery: initialQuery ?? ''),
    ),
  );
}

class _VenuePickerSheet extends ConsumerStatefulWidget {
  const _VenuePickerSheet({required this.initialQuery});

  final String initialQuery;

  @override
  ConsumerState<_VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends ConsumerState<_VenuePickerSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final venues =
        ref.watch(venueSearchProvider(_query)).valueOrNull ?? const <Venue>[];
    final trimmed = _query.trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wo bist du?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Gasthaus suchen oder Ort eintippen',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final venue in venues)
                    ListTile(
                      dense: true,
                      leading: Text(venueCategoryEmoji(venue.category),
                          style: const TextStyle(fontSize: 22)),
                      title: Text(venue.name),
                      subtitle: Text([
                        venueCategoryLabel(venue.category),
                        if (venue.city != null && venue.city!.isNotEmpty)
                          venue.city!,
                        if (venue.priceHalfL != null)
                          '0,5 l € ${venue.priceHalfL!.toStringAsFixed(2)}',
                      ].join(' · ')),
                      trailing: venue.verified
                          ? Icon(Icons.verified_outlined,
                              size: 18, color: scheme.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(
                          (venueId: venue.id, venueName: venue.name)),
                    ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add_business_outlined),
                    title: const Text('Neues Gasthaus anlegen'),
                    subtitle: const Text(
                        'Mit Preisen & Öffnungszeiten – hilft allen BrewMates'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(Uri(
                        path: '/venues/add',
                        queryParameters: {
                          if (trimmed.isNotEmpty) 'name': trimmed,
                        },
                      ).toString());
                    },
                  ),
                  if (trimmed.isNotEmpty)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.edit_outlined),
                      title: Text('„$trimmed" als Freitext verwenden'),
                      onTap: () => Navigator.of(context)
                          .pop((venueId: null, venueName: trimmed)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
