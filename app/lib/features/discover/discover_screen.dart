import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/db/database.dart';
import '../../data/location_service.dart';
import '../../data/providers.dart';
import '../../data/venue_open.dart';
import '../../data/venue_sync.dart' show venueCategoryEmoji;
import '../../widgets/venue_tile.dart';

/// Entdecken: **ein** Ort für Biere, Brauereien und Gasthäuser.
///
/// Vorher waren die Gasthäuser ein eigener Bildschirm, erreichbar über
/// einen Knopf auf der Karte — man musste also wissen, dass es ihn gibt.
/// Brauereien fanden sich nur über die Biersuche. Wer etwas in seiner
/// Nähe suchte, hatte drei Wege und keinen davon naheliegend.
///
/// Jetzt: eine Suchzeile, drei Bereiche, und bei Orten die Sortierung
/// nach Entfernung. Der Standort wird still im Hintergrund geholt; ohne
/// ihn bleibt die Liste alphabetisch, statt leer zu sein.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

enum _Bereich { biere, brauereien, gasthaeuser }

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _sucheController = TextEditingController();
  String _suche = '';
  _Bereich _bereich = _Bereich.biere;

  /// Gasthaus-Filter, übernommen aus der abgelösten Liste.
  String? _kategorie;
  bool _nurGeoeffnet = false;

  LatLng? _hier;

  @override
  void initState() {
    super.initState();
    // Standort still im Hintergrund. Er ist ein Zusatz, keine Bedingung:
    // Ohne ihn sortiert die Liste alphabetisch weiter.
    Future(() async {
      final ergebnis =
          await ref.read(locationServiceProvider).getCurrentPosition();
      if (!mounted || ergebnis is! LocationGranted) return;
      setState(() => _hier = LatLng(ergebnis.latitude, ergebnis.longitude));
    });
  }

  @override
  void dispose() {
    _sucheController.dispose();
    super.dispose();
  }

  double? _entfernung(double? lat, double? lng) {
    if (_hier == null || lat == null || lng == null) return null;
    return const Distance()(_hier!, LatLng(lat, lng)) / 1000.0;
  }

  String _entfernungText(double? km) =>
      km == null ? '' : (km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Entdecken')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _sucheController,
              decoration: InputDecoration(
                hintText: 'Bier, Brauerei oder Gasthaus',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _suche.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _sucheController.clear();
                          setState(() => _suche = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _suche = v),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<_Bereich>(
            segments: const [
              ButtonSegment(value: _Bereich.biere, label: Text('Biere')),
              ButtonSegment(
                  value: _Bereich.brauereien, label: Text('Brauereien')),
              ButtonSegment(
                  value: _Bereich.gasthaeuser, label: Text('Gasthäuser')),
            ],
            selected: {_bereich},
            onSelectionChanged: (s) => setState(() => _bereich = s.first),
          ),
          if (_bereich == _Bereich.gasthaeuser) _gasthausFilter(theme),
          if (_hier == null && _bereich != _Bereich.biere)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Ohne Standortfreigabe alphabetisch sortiert.',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          const SizedBox(height: 4),
          Expanded(child: _liste()),
        ],
      ),
    );
  }

  Widget _gasthausFilter(ThemeData theme) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            FilterChip(
              label: const Text('● jetzt geöffnet'),
              selected: _nurGeoeffnet,
              onSelected: (v) => setState(() => _nurGeoeffnet = v),
            ),
            const SizedBox(width: 8),
            for (final k in const ['gasthaus', 'bar', 'brauerei', 'shop'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('${venueCategoryEmoji(k)} $k'),
                  selected: _kategorie == k,
                  onSelected: (v) =>
                      setState(() => _kategorie = v ? k : null),
                ),
              ),
          ],
        ),
      );

  Widget _liste() {
    switch (_bereich) {
      case _Bereich.biere:
        return _biere();
      case _Bereich.brauereien:
        return _brauereien();
      case _Bereich.gasthaeuser:
        return _gasthaeuser();
    }
  }

  Widget _biere() {
    final treffer =
        ref.watch(beersProvider((search: _suche, style: null))).valueOrNull ??
            const <BeerWithBrewery>[];
    if (treffer.isEmpty) return const _Leer(text: 'Kein Bier gefunden.');
    return ListView.builder(
      itemCount: treffer.length,
      itemBuilder: (_, i) {
        final t = treffer[i];
        return ListTile(
          leading: Text(t.beer.isAlcoholFree ? '💧' : '🍺',
              style: const TextStyle(fontSize: 24)),
          title: Text(t.beer.name),
          subtitle: Text('${t.brewery.name} · ${t.beer.style}'),
          onTap: () => context.push('/beer/${t.beer.id}'),
        );
      },
    );
  }

  Widget _brauereien() {
    // Ohne Suchbegriff die Brauereien mit Position: Das ist die Menge,
    // für die „in deiner Nähe" überhaupt eine Bedeutung hat.
    final alle = _suche.trim().isEmpty
        ? (ref.watch(breweriesWithLocationProvider).valueOrNull ??
            const <Brewery>[])
        : (ref.watch(brewerySearchProvider(_suche)).valueOrNull ??
            const <Brewery>[]);

    final sortiert = [...alle];
    sortiert.sort((a, b) {
      final da = _entfernung(a.latitude, a.longitude);
      final db = _entfernung(b.latitude, b.longitude);
      if (da == null && db == null) return a.name.compareTo(b.name);
      // Ohne Position ans Ende, statt sie zu verstecken: Eine Brauerei
      // ohne Koordinaten ist trotzdem eine Brauerei.
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    if (sortiert.isEmpty) {
      return const _Leer(text: 'Keine Brauerei gefunden.');
    }
    return ListView.builder(
      itemCount: sortiert.length,
      itemBuilder: (_, i) {
        final b = sortiert[i];
        final km = _entfernung(b.latitude, b.longitude);
        return ListTile(
          leading: const Text('🏭', style: TextStyle(fontSize: 24)),
          title: Text(b.name),
          subtitle: Text([b.city, b.country].where((s) => s.isNotEmpty).join(' · ')),
          trailing: km == null
              ? null
              : Text(_entfernungText(km),
                  style: Theme.of(context).textTheme.labelMedium),
          onTap: () => context.push('/brewery/${b.id}'),
        );
      },
    );
  }

  Widget _gasthaeuser() {
    var alle = ref.watch(venuesWithLocationProvider).valueOrNull ??
        const <Venue>[];

    final suche = _suche.trim().toLowerCase();
    if (suche.isNotEmpty) {
      alle = [
        for (final v in alle)
          if (v.name.toLowerCase().contains(suche) ||
              (v.city ?? '').toLowerCase().contains(suche))
            v,
      ];
    }
    if (_kategorie != null) {
      alle = [for (final v in alle) if (v.category == _kategorie) v];
    }
    if (_nurGeoeffnet) alle = openNow(alle, DateTime.now());

    final sortiert = [...alle];
    sortiert.sort((a, b) {
      final da = _entfernung(a.latitude, a.longitude);
      final db = _entfernung(b.latitude, b.longitude);
      if (da == null && db == null) return a.name.compareTo(b.name);
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    if (sortiert.isEmpty) {
      return const _Leer(text: 'Kein Gasthaus gefunden.');
    }
    return ListView.builder(
      itemCount: sortiert.length,
      itemBuilder: (_, i) {
        final v = sortiert[i];
        return VenueTile(
          venue: v,
          distanceKm: _entfernung(v.latitude, v.longitude),
        );
      },
    );
  }
}

class _Leer extends StatelessWidget {
  const _Leer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
