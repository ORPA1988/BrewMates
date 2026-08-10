import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/demo_data.dart';

/// Live-Karte: zeigt ausschließlich aktive Sessions bestätigter Freunde
/// (Privatsphäre-Modell siehe docs/04-datenmodell.md).
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = DemoData.activeSessions()
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Karte')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: sessions.isNotEmpty
              ? LatLng(sessions.first.latitude!, sessions.first.longitude!)
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
              for (final s in sessions)
                Marker(
                  point: LatLng(s.latitude!, s.longitude!),
                  width: 48,
                  height: 48,
                  child: Tooltip(
                    message:
                        '${s.host.displayName} @ ${s.venueName ?? 'unterwegs'}',
                    child: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      child: Text(s.host.displayName[0]),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
