import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/db/database.dart';
import '../../data/location_service.dart';
import '../../data/providers.dart';
import '../../data/venue_sync.dart';
import '../../domain/opening_hours.dart';
import '../../widgets/venue_tile.dart';

/// Sortierungen der Gasthausliste.
enum VenueSort { alphabetical, distance, price, updated }

/// Pure Sortier-/Filterlogik (ohne Widgets testbar).
/// [here] wird nur für [VenueSort.distance] gebraucht; Venues ohne
/// Koordinaten/Preis/Zeitstempel sortieren jeweils ans Ende.
List<Venue> sortVenues(List<Venue> venues, VenueSort sort, {LatLng? here}) {
  final sorted = [...venues];
  const distance = Distance();
  double? km(Venue v) => (here == null ||
          v.latitude == null ||
          v.longitude == null)
      ? null
      : distance(here, LatLng(v.latitude!, v.longitude!)) / 1000.0;

  int compareNullableAsc(Comparable<Object>? a, Comparable<Object>? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1; // nulls ans Ende
    if (b == null) return -1;
    return a.compareTo(b as Object);
  }

  switch (sort) {
    case VenueSort.alphabetical:
      sorted.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case VenueSort.distance:
      sorted.sort((a, b) => compareNullableAsc(km(a), km(b)));
    case VenueSort.price:
      sorted.sort(
          (a, b) => compareNullableAsc(a.priceHalfL, b.priceHalfL));
    case VenueSort.updated:
      // Jüngste zuerst; ohne Zeitstempel ans Ende (Nulls explizit, weil
      // das bloße Vertauschen der Argumente sie nach vorn sortieren würde).
      sorted.sort((a, b) {
        if (a.updatedAt == null && b.updatedAt == null) return 0;
        if (a.updatedAt == null) return 1;
        if (b.updatedAt == null) return -1;
        return b.updatedAt!.compareTo(a.updatedAt!);
      });
  }
  return sorted;
}

/// „Jetzt geöffnet"-Filter (pur, testbar): behält nur Venues MIT
/// strukturierten Öffnungszeiten, die zu [now] geöffnet sind.
List<Venue> openNow(List<Venue> venues, DateTime now) => [
      for (final v in venues)
        if (isOpenAt(parseOpeningHours(v.openingHoursJson), now)) v,
    ];

/// Entfernung in km zu [here] (null, wenn nicht bestimmbar).
double? venueDistanceKm(Venue v, LatLng? here) {
  if (here == null || v.latitude == null || v.longitude == null) return null;
  return const Distance()(here, LatLng(v.latitude!, v.longitude!)) / 1000.0;
}

/// Gasthausliste: alle Gasthäuser der gemeinsamen DB, durchsuchbar,
/// filterbar nach Kategorie und sortierbar (A–Z, Nähe, Preis, Aktualität).
class VenuesListScreen extends ConsumerStatefulWidget {
  const VenuesListScreen({super.key});

  @override
  ConsumerState<VenuesListScreen> createState() => _VenuesListScreenState();
}

class _VenuesListScreenState extends ConsumerState<VenuesListScreen> {
  String _search = '';
  String? _category;
  bool _openNowOnly = false;
  VenueSort _sort = VenueSort.alphabetical;
  LatLng? _here;
  bool _locationTried = false;

  @override
  void initState() {
    super.initState();
    // Standort still im Hintergrund holen – „📍 Nähe" wird erst damit aktiv.
    Future(() async {
      final result =
          await ref.read(locationServiceProvider).getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _locationTried = true;
        if (result is LocationGranted) {
          _here = LatLng(result.latitude, result.longitude);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = ref.watch(allVenuesProvider).valueOrNull ?? const <Venue>[];
    final myUid = ref.watch(onlineUserProvider).valueOrNull?.id;
    final myLevel = ref.watch(accountLevelProvider).valueOrNull?.level ?? 0;

    final term = _search.trim().toLowerCase();
    var filtered = [
      for (final v in all)
        if ((_category == null || v.category == _category) &&
            (term.isEmpty ||
                v.name.toLowerCase().contains(term) ||
                (v.city ?? '').toLowerCase().contains(term)))
          v,
    ];
    if (_openNowOnly) filtered = openNow(filtered, DateTime.now());
    final venues = sortVenues(filtered, _sort, here: _here);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🍽 Gasthäuser'),
        actions: [
          IconButton(
            tooltip: 'Neues Gasthaus anlegen',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/venues/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Gasthaus oder Ort suchen …',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('● Jetzt geöffnet'),
                  selected: _openNowOnly,
                  onSelected: (selected) =>
                      setState(() => _openNowOnly = selected),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Alle'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final category in venueCategories) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('${venueCategoryEmoji(category)} '
                        '${venueCategoryLabel(category)}'),
                    selected: _category == category,
                    onSelected: (selected) => setState(
                        () => _category = selected ? category : null),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<VenueSort>(
              segments: [
                const ButtonSegment(
                    value: VenueSort.alphabetical, label: Text('A–Z')),
                ButtonSegment(
                  value: VenueSort.distance,
                  label: const Text('📍 Nähe'),
                  enabled: _here != null,
                  tooltip: _here == null
                      ? (_locationTried
                          ? 'Standort nicht verfügbar'
                          : 'Standort wird ermittelt …')
                      : null,
                ),
                const ButtonSegment(
                    value: VenueSort.price, label: Text('🍺 Preis')),
                const ButtonSegment(
                    value: VenueSort.updated, label: Text('🕒 Aktuell')),
              ],
              selected: {_sort},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _sort = selection.first),
            ),
          ),
          Expanded(
            child: venues.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🍽', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            all.isEmpty
                                ? 'Noch keine Gasthäuser in der Datenbank.'
                                : 'Nichts gefunden – Filter anpassen?',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          if (all.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Leg das erste an – mit Preisen und '
                              'Öffnungszeiten hilft es allen BrewMates!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => context.push('/venues/add'),
                              icon: const Icon(Icons.add_business_outlined),
                              label: const Text('Erstes Gasthaus anlegen'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final venue in venues)
                        VenueTile(
                          venue: venue,
                          canEdit: myUid != null &&
                              (venue.createdBy == myUid || myLevel >= 2),
                          distanceKm: _sort == VenueSort.distance
                              ? venueDistanceKm(venue, _here)
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
