import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/external_links.dart';
import '../core/format.dart';
import '../data/db/database.dart';
import '../data/venue_sync.dart';
import '../domain/opening_hours.dart';

/// Schnellansicht für Orte (Gasthäuser UND Brauereien): ein Bottom-Sheet
/// mit den wichtigsten Fakten (Adresse, Öffnungszeiten, Bierpreise),
/// Google-Maps-Route und optionalen Aktionen. Karte und Entdecken-Tab
/// öffnen dieses Sheet statt direkt in Detailseiten zu springen.
class PlaceQuickData {
  const PlaceQuickData({
    required this.emoji,
    required this.name,
    this.subtitle,
    this.verified = false,
    this.address,
    this.openingHours,
    this.priceHalfL,
    this.priceThirdL,
    this.latitude,
    this.longitude,
    this.mapsQuery,
    this.updatedAt,
    this.detailRoute,
    this.editRoute,
    this.websiteUrl,
    this.openingIntervals = const [],
  });

  factory PlaceQuickData.fromVenue(Venue v, {bool canEdit = false}) =>
      PlaceQuickData(
        emoji: venueCategoryEmoji(v.category),
        name: v.name,
        subtitle: [
          venueCategoryLabel(v.category),
          if (v.city != null && v.city!.isNotEmpty) v.city!,
        ].join(' · '),
        verified: v.verified,
        address: v.address,
        openingHours: v.openingHours,
        priceHalfL: v.priceHalfL,
        priceThirdL: v.priceThirdL,
        latitude: v.latitude,
        longitude: v.longitude,
        mapsQuery: '${v.name}${v.city == null ? '' : ', ${v.city}'}',
        updatedAt: v.updatedAt,
        editRoute: canEdit ? '/venue/${v.id}/edit' : null,
        openingIntervals: parseOpeningHours(v.openingHoursJson),
      );

  factory PlaceQuickData.fromBrewery(Brewery b) => PlaceQuickData(
        emoji: '🏭',
        name: b.name,
        subtitle: 'Brauerei · ${b.city}, ${b.country}',
        address: b.address,
        latitude: b.latitude,
        longitude: b.longitude,
        mapsQuery: '${b.name}, ${b.city}',
        detailRoute: '/brewery/${b.id}',
        websiteUrl: b.website,
      );

  final String emoji;
  final String name;
  final String? subtitle;
  final bool verified;
  final String? address;
  final String? openingHours;
  final double? priceHalfL;
  final double? priceThirdL;
  final double? latitude;
  final double? longitude;
  final String? mapsQuery;
  final DateTime? updatedAt;
  final String? detailRoute;
  final String? editRoute;
  final String? websiteUrl;

  /// Strukturierte Öffnungszeiten (leer = nur Freitext bekannt).
  final List<OpeningInterval> openingIntervals;
}

final _euro = NumberFormat.currency(locale: 'de_AT', symbol: '€');

Future<void> showPlaceQuickSheet(BuildContext context, PlaceQuickData place) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final scheme = theme.colorScheme;
      final status = openingStatus(place.openingIntervals, DateTime.now());
      final facts = <(IconData, String)>[
        if (place.address != null && place.address!.isNotEmpty)
          (Icons.place_outlined, place.address!),
        if (place.openingHours != null && place.openingHours!.isNotEmpty)
          (Icons.schedule_outlined, place.openingHours!),
        if (place.priceHalfL != null)
          (
            Icons.sports_bar_outlined,
            '0,5 l ${_euro.format(place.priceHalfL)}'
                '${place.priceThirdL != null ? ' · 0,3 l ${_euro.format(place.priceThirdL)}' : ''}',
          )
        else if (place.priceThirdL != null)
          (Icons.sports_bar_outlined, '0,3 l ${_euro.format(place.priceThirdL)}'),
      ];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(place.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.name, style: theme.textTheme.titleLarge),
                        if (place.subtitle != null)
                          Text(place.subtitle!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (place.verified)
                    Tooltip(
                      message: 'Von der Community verifiziert',
                      child: Icon(Icons.verified_outlined,
                          color: scheme.primary),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    status.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: status.open ? scheme.primary : scheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              for (final (icon, text) in facts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                          child:
                              Text(text, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              if (facts.isEmpty)
                Text(
                  'Noch keine Details – hilf mit und trag Preise oder '
                  'Öffnungszeiten ein!',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              if (place.updatedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Stand: ${timeAgo(place.updatedAt!.toLocal())}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (place.latitude != null || place.mapsQuery != null)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Google Maps'),
                      onPressed: () async => launchUrl(
                        googleMapsSearchUri(
                          lat: place.latitude,
                          lng: place.latitude == null ? null : place.longitude,
                          query: place.mapsQuery ?? place.name,
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  if (place.detailRoute != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Details'),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push(place.detailRoute!);
                      },
                    ),
                  if (place.editRoute != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Bearbeiten'),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push(place.editRoute!);
                      },
                    ),
                  if (place.websiteUrl != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.language, size: 18),
                      label: const Text('Website'),
                      onPressed: () async => launchUrl(
                        Uri.parse(place.websiteUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
