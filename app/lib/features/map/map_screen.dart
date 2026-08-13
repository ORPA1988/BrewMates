import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';

/// Formulierung des Aktiv-Zählers rechts oben – zentral anpassbar.
String activeUsersLabel(int n) =>
    n == 1 ? '🍻 1 weiterer BrewMate aktiv' : '🍻 $n weitere BrewMates aktiv';

/// Live-Karte: aktive Sessions bestätigter Freunde (Privatsphäre-Modell
/// siehe docs/04-datenmodell.md) plus optionale Ebene mit österreichischen
/// Brauereistandorten aus der Community-Datenbank.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _showBreweries = true;
  Timer? _boundsDebounce;
  final _mapController = MapController();

  // Wien – Fokusmarkt Österreich.
  static const _fallbackCenter = LatLng(48.2082, 16.3738);

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Sichtbaren Ausschnitt (entprellt) melden – Grundlage für den
  /// „x weitere BrewMates aktiv"-Zähler.
  void _reportBounds(LatLngBounds bounds) {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(mapBoundsProvider.notifier).state = (
        minLat: bounds.south,
        minLng: bounds.west,
        maxLat: bounds.north,
        maxLng: bounds.east,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = ref.watch(activeSessionsProvider).valueOrNull ?? [];
    final located = sessions
        .where(
            (d) => d.session.latitude != null && d.session.longitude != null)
        .toList();
    final breweries = _showBreweries
        ? (ref.watch(breweriesWithLocationProvider).valueOrNull ??
            const <Brewery>[])
        : const <Brewery>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Karte')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: located.isNotEmpty
                  ? LatLng(located.first.session.latitude!,
                      located.first.session.longitude!)
                  : _fallbackCenter,
              initialZoom: located.isNotEmpty ? 13 : 7,
              onMapReady: () =>
                  _reportBounds(_mapController.camera.visibleBounds),
              onMapEvent: (event) => _reportBounds(event.camera.visibleBounds),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.brewmates.app',
              ),
              MarkerLayer(
                markers: [
                  for (final b in breweries) _breweryMarker(context, b),
                  for (final d in located) _sessionMarker(context, d),
                ],
              ),
            ],
          ),
          // Aktiv-Zähler rechts oben: Freunde stehen als Pins auf der
          // Karte, alle übrigen aktiven Nutzer im Ausschnitt erscheinen
          // nur als Zahl – nie mit Position.
          if ((ref.watch(otherActiveCountProvider).valueOrNull ?? 0) > 0)
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Wer nicht mit dir befreundet ist, wird nur '
                          'gezählt – nie auf der Karte verortet.'),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Text(
                      activeUsersLabel(
                          ref.watch(otherActiveCountProvider).valueOrNull ??
                              0),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Ebenen-Umschalter + Datenschutz-Hinweis (links, damit der
          // Aktiv-Zähler rechts Platz hat).
          Positioned(
            top: 12,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '🔒 Nur Freunde · nur während aktiver Sessions',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const SizedBox(height: 8),
                FilterChip(
                  label: const Text('🏭 Brauereien'),
                  selected: _showBreweries,
                  onSelected: (v) => setState(() => _showBreweries = v),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: theme.colorScheme.surface.withOpacity(0.7),
              child: Text(
                '© OpenStreetMap',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          if (located.isEmpty)
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Keine aktiven Sessions. Starte eine – '
                        'deine Freunde sehen dich hier. 🍺',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.push('/session/start'),
                        child: const Text('🍻 Session starten'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Marker _breweryMarker(BuildContext context, Brewery b) {
    final theme = Theme.of(context);
    return Marker(
      point: LatLng(b.latitude!, b.longitude!),
      width: 90,
      height: 52,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => context.push('/brewery/${b.id}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏭', style: TextStyle(fontSize: 20)),
            Container(
              constraints: const BoxConstraints(maxWidth: 88),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                b.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _sessionMarker(BuildContext context, SessionDetails d) {
    final theme = Theme.of(context);
    final mine = d.host.isMe;
    return Marker(
      point: LatLng(d.session.latitude!, d.session.longitude!),
      width: 96,
      height: mine ? 84 : 70,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => context.push('/session/${d.session.id}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(mine ? 2 : 0),
              decoration: mine
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.colorScheme.primary, width: 3),
                    )
                  : null,
              child: CircleAvatar(
                radius: mine ? 22 : 18,
                backgroundColor: theme.colorScheme.surface,
                child: Text(
                  d.host.avatarEmoji,
                  style: TextStyle(fontSize: mine ? 22 : 18),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              constraints: const BoxConstraints(maxWidth: 90),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                d.session.venueName ?? 'unterwegs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
