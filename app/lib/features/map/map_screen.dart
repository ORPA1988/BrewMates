import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';

/// Live-Karte: zeigt ausschließlich aktive Sessions bestätigter Freunde
/// (Privatsphäre-Modell siehe docs/04-datenmodell.md).
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(activeSessionsProvider).valueOrNull ?? [];
    final located = sessions
        .where((d) =>
            d.session.latitude != null && d.session.longitude != null)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Karte')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: located.isNotEmpty
                  ? LatLng(located.first.session.latitude!,
                      located.first.session.longitude!)
                  : const LatLng(48.1374, 11.5755),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.brewmates.app',
              ),
              MarkerLayer(
                markers: [
                  for (final d in located) _sessionMarker(context, d),
                ],
              ),
            ],
          ),
          // Datenschutz-Hinweis: was die Karte zeigt – und was nicht.
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
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
