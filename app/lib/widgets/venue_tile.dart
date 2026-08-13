import 'package:flutter/material.dart';

import '../data/db/database.dart';
import '../data/venue_sync.dart';
import 'place_quick_sheet.dart';

/// Listenzeile für ein Gasthaus (Entdecken-Treffer, Gasthausliste).
/// Tap öffnet die Schnellansicht; optional mit Entfernungsangabe.
class VenueTile extends StatelessWidget {
  const VenueTile({
    super.key,
    required this.venue,
    this.canEdit = false,
    this.distanceKm,
  });

  final Venue venue;
  final bool canEdit;

  /// Entfernung zum Standort in km (null = unbekannt/nicht relevant).
  final double? distanceKm;

  String get _distanceLabel => distanceKm! < 1
      ? '${(distanceKm! * 1000).round()} m'
      : '${distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Text(venueCategoryEmoji(venue.category),
            style: const TextStyle(fontSize: 26)),
        title: Text(venue.name),
        subtitle: Text([
          venueCategoryLabel(venue.category),
          if (venue.city != null && venue.city!.isNotEmpty) venue.city!,
          if (venue.priceHalfL != null)
            '0,5 l € ${venue.priceHalfL!.toStringAsFixed(2)}',
          if (distanceKm != null) '📍 $_distanceLabel',
        ].join(' · ')),
        trailing: venue.verified
            ? Icon(Icons.verified_outlined, size: 20, color: scheme.primary)
            : null,
        onTap: () async => showPlaceQuickSheet(
            context, PlaceQuickData.fromVenue(venue, canEdit: canEdit)),
      ),
    );
  }
}
