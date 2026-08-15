import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/venue_sync.dart';
import '../../widgets/place_quick_sheet.dart';
import '../../data/venue_open.dart';

/// Formulierung des Aktiv-Zählers rechts oben – zentral anpassbar.
/// Anbieter der Kartenkacheln.
///
/// Existiert als Provider, damit der Widget-Test die Karte prüfen kann,
/// ohne Kacheln zu laden: Im Test gibt es kein Netz, jede Anfrage
/// scheitert, und `flutter_map` versucht es endlos weiter — der Test
/// hängt, statt etwas auszusagen. Produktiv ist es der Normalfall.
final mapTileProviderProvider =
    Provider<TileProvider>((ref) => NetworkTileProvider());

String activeUsersLabel(int n) =>
    n == 1 ? '🍻 1 weiterer BrewMate aktiv' : '🍻 $n weitere BrewMates aktiv';

/// Live-Karte: aktive Sessions bestätigter Freunde (Privatsphäre-Modell
/// siehe docs/04-datenmodell.md) plus optionale, abschaltbare Ebene mit
/// Brauereistandorten (Österreich + Bayern) aus der Community-Datenbank.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _showBreweries = true;
  bool _showVenues = true;
  Timer? _boundsDebounce;
  final _mapController = MapController();

  /// Aktueller Zoom (entprellt aktualisiert). Unterhalb von
  /// [_labelZoom] werden Brauereien nur als Punkte gezeichnet –
  /// bei ~50 Brauereien (AT + Bayern) wäre die Länder-Ansicht
  /// sonst mit Namensschildern zugepflastert.
  double _zoom = 7;
  static const _labelZoom = 9.0;

  // Wien – Fokusmarkt Österreich.
  static const _fallbackCenter = LatLng(48.2082, 16.3738);

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Sichtbaren Ausschnitt (entprellt) melden – Grundlage für den
  /// „x weitere BrewMates aktiv"-Zähler und die Brauerei-Darstellung
  /// (Punkt vs. Symbol mit Namen).
  void _reportBounds(LatLngBounds bounds, double zoom) {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(mapBoundsProvider.notifier).state = (
        minLat: bounds.south,
        minLng: bounds.west,
        maxLat: bounds.north,
        maxLng: bounds.east,
      );
      if ((zoom < _labelZoom) != (_zoom < _labelZoom)) {
        setState(() => _zoom = zoom);
      } else {
        _zoom = zoom;
      }
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
    var venues = _showVenues
        ? (ref.watch(venuesWithLocationProvider).valueOrNull ??
            const <Venue>[])
        : const <Venue>[];
    // Nicht mehr filtern, sondern faerben: Ein geschlossenes Gasthaus ist
    // eine nuetzliche Information (morgen wieder da, Preis bekannt), kein
    // Grund es verschwinden zu lassen. Wer es ausblendet, sieht auf der
    // Karte ein Loch und weiss nicht, ob dort nichts ist oder nur zu.
    // Bearbeiten im Quick-Sheet: Ersteller immer, sonst ab Stammgast –
    // die RLS bleibt die eigentliche Durchsetzung.
    final myUid = ref.watch(onlineUserProvider).valueOrNull?.id;
    final myLevel =
        ref.watch(accountLevelProvider).valueOrNull?.level ?? 0;
    bool canEditVenue(Venue v) =>
        myUid != null && (v.createdBy == myUid || myLevel >= 2);

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
              onMapReady: () => _reportBounds(
                  _mapController.camera.visibleBounds,
                  _mapController.camera.zoom),
              onMapEvent: (event) => _reportBounds(
                  event.camera.visibleBounds, event.camera.zoom),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.brewmates.app',
                tileProvider: ref.watch(mapTileProviderProvider),
              ),
              MarkerLayer(
                markers: [
                  for (final b in breweries)
                    _zoom < _labelZoom
                        ? _placeDot(
                            context,
                            lat: b.latitude!,
                            lng: b.longitude!,
                            color: theme.colorScheme.tertiary,
                            onTap: () => showPlaceQuickSheet(
                                context, PlaceQuickData.fromBrewery(b)),
                          )
                        : _placeMarker(
                            context,
                            lat: b.latitude!,
                            lng: b.longitude!,
                            emoji: '🏭',
                            label: b.name,
                            onTap: () => showPlaceQuickSheet(
                                context, PlaceQuickData.fromBrewery(b)),
                          ),
                  for (final v in venues)
                    _zoom < _labelZoom
                        ? _placeDot(
                            context,
                            lat: v.latitude!,
                            lng: v.longitude!,
                            color: venueFarbe(theme, v, DateTime.now()),
                            onTap: () => showPlaceQuickSheet(
                                context, PlaceQuickData.fromVenue(v, canEdit: canEditVenue(v))),
                          )
                        : _placeMarker(
                            context,
                            lat: v.latitude!,
                            lng: v.longitude!,
                            emoji: venueCategoryEmoji(v.category),
                            farbe: venueFarbe(theme, v, DateTime.now()),
                            // Preis-Radar: ab Zoom 12 steht der 0,5-l-Preis
                            // direkt am Namensschild.
                            label: (_zoom >= 12 && v.priceHalfL != null)
                                ? '${v.name} · '
                                    '${v.priceHalfL!.toStringAsFixed(2)}'
                                : v.name,
                            onTap: () => showPlaceQuickSheet(
                                context, PlaceQuickData.fromVenue(v, canEdit: canEditVenue(v))),
                          ),
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
                const SizedBox(height: 4),
                FilterChip(
                  label: const Text('🍽 Gasthäuser'),
                  selected: _showVenues,
                  onSelected: (v) => setState(() => _showVenues = v),
                ),
                if (_showVenues) ...[
                  const SizedBox(height: 6),
                  // Legende statt Filter: Die Farbe sagt, was der Filter
                  // frueher weggenommen hat.
                  _OeffnungsLegende(),
                ],
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

  /// Herausgezoomt: Ort (Brauerei/Gasthaus) nur als kleiner Punkt – bleibt
  /// antippbar, beim Heranzoomen (ab Zoom [_labelZoom]) erscheinen
  /// Symbol + Name. Tap öffnet die Schnellansicht.
  Marker _placeDot(
    BuildContext context, {
    required double lat,
    required double lng,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Marker(
      point: LatLng(lat, lng),
      width: 16,
      height: 16,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: theme.colorScheme.surface, width: 2),
          ),
        ),
      ),
    );
  }

  Marker _placeMarker(
    BuildContext context, {
    required double lat,
    required double lng,
    required String emoji,
    required String label,
    required VoidCallback onTap,
    Color? farbe,
  }) {
    final theme = Theme.of(context);
    return Marker(
      point: LatLng(lat, lng),
      width: 90,
      height: 52,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            Container(
              constraints: const BoxConstraints(maxWidth: 88),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
                // Der farbige Rand traegt die Oeffnungsangabe auch dort,
                // wo Namensschilder sichtbar sind.
                border: farbe == null
                    ? null
                    : Border.all(color: farbe, width: 1.5),
              ),
              child: Text(
                label,
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

/// Legende zu den Gasthaus-Farben.
///
/// Sie ersetzt den frueheren Filter „Jetzt geoeffnet". Ein Filter nimmt
/// Information weg, eine Legende gibt sie: Geschlossen heisst nicht
/// uninteressant — der Preis steht trotzdem da, und morgen ist wieder auf.
class _OeffnungsLegende extends StatelessWidget {
  const _OeffnungsLegende();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget zeile(Color farbe, String text) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: farbe, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(text, style: theme.textTheme.labelSmall),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        zeile(const Color(0xFF1E6FD9), 'geöffnet'),
        zeile(const Color(0xFFC62828), 'geschlossen'),
        zeile(theme.colorScheme.secondary, 'keine Zeiten'),
      ],
    );
  }
}
