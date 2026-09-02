/// „Jetzt geöffnet" — geteilt zwischen Entdecken-Bildschirm und Karte.
///
/// Stand bis 2026-08-15 in `features/venues/venues_list_screen.dart` und
/// wurde von `features/map/` importiert. Das war ein Cross-Feature-Import
/// und damit ein Verstoß gegen eine der nicht verhandelbaren Regeln — er
/// blieb unbemerkt, weil der Architektur-Test nur absolute Pfade prüfte
/// und dieser relativ geschrieben war (`../venues/…`).
///
/// Hier statt in `domain/`, weil die Funktionen auf dem Drift-Typ [Venue]
/// arbeiten. Die eigentliche Öffnungszeiten-Logik liegt weiterhin
/// datenbankfrei in `domain/opening_hours.dart`.
library;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../domain/opening_hours.dart';
import 'db/database.dart';

/// Nur die Gasthäuser, die zu [now] geöffnet haben.
List<Venue> openNow(List<Venue> venues, DateTime now) => [
      for (final v in venues)
        if (isOpenAt(parseOpeningHours(v.openingHoursJson), now)) v,
    ];

/// Hat das Gasthaus zu [now] geöffnet? `null` = keine Zeiten hinterlegt.
///
/// Die Unterscheidung zwischen „geschlossen" und „wissen wir nicht" ist
/// wichtig: Eine rote Markierung an einem Gasthaus, dessen Zeiten
/// schlicht fehlen, wäre eine Behauptung, die wir nicht belegen können.
bool? istGeoeffnet(Venue v, DateTime now) {
  final zeiten = parseOpeningHours(v.openingHoursJson);
  if (zeiten.isEmpty) return null;
  return isOpenAt(zeiten, now);
}

/// Farbe der Kartenmarkierung: blau geöffnet, rot geschlossen.
///
/// Wo keine Öffnungszeiten hinterlegt sind, bleibt es bei der neutralen
/// Themenfarbe — lieber keine Aussage als eine falsche. Genau deshalb
/// ersetzt die Farbe den früheren Filter „Jetzt geöffnet": Der ließ
/// geschlossene Häuser verschwinden, und auf der Karte blieb ein Loch,
/// dem man nicht ansah, ob dort nichts ist oder nur gerade zu.
Color venueFarbe(ThemeData theme, Venue v, DateTime now) {
  final offen = istGeoeffnet(v, now);
  if (offen == null) return theme.colorScheme.secondary;
  return offen ? const Color(0xFF1E6FD9) : const Color(0xFFC62828);
}

/// Sortierungen fuer Ortslisten. Lag bis 2026-09-02 in der alten
/// Gasthausliste, die nach dem Umbau auf Entdecken von keiner Stelle mehr
/// erreichbar war — und mit ihr Preis- und Aktualitaets-Sortierung.
enum VenueSort { distance, alphabetical, price, updated }

String venueSortLabel(VenueSort s) => switch (s) {
      VenueSort.distance => '📍 Nähe',
      VenueSort.alphabetical => 'A–Z',
      VenueSort.price => '€ Preis',
      VenueSort.updated => 'Aktuell',
    };

double? venueDistanceKm(Venue v, LatLng? here) {
  if (here == null || v.latitude == null || v.longitude == null) return null;
  return const Distance()(here, LatLng(v.latitude!, v.longitude!)) / 1000.0;
}

/// Reine Sortierlogik (ohne Widgets testbar). Orte ohne Koordinaten,
/// Preis oder Zeitstempel sortieren jeweils ans Ende — sie verschwinden
/// nicht: Ein Gasthaus ohne Position ist trotzdem ein Gasthaus.
List<Venue> sortVenues(List<Venue> venues, VenueSort sort, {LatLng? here}) {
  final sorted = [...venues];
  int nullsLast<T extends Comparable<Object>>(T? a, T? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  switch (sort) {
    case VenueSort.alphabetical:
      sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case VenueSort.distance:
      sorted.sort((a, b) {
        final c = nullsLast(venueDistanceKm(a, here), venueDistanceKm(b, here));
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    case VenueSort.price:
      sorted.sort((a, b) => nullsLast(a.priceHalfL, b.priceHalfL));
    case VenueSort.updated:
      sorted.sort((a, b) {
        if (a.updatedAt == null && b.updatedAt == null) return 0;
        if (a.updatedAt == null) return 1;
        if (b.updatedAt == null) return -1;
        return b.updatedAt!.compareTo(a.updatedAt!);
      });
  }
  return sorted;
}
