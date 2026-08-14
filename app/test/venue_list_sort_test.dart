import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/features/venues/venues_list_screen.dart';

Venue _venue(String id, String name,
        {double? lat,
        double? lng,
        double? priceHalf,
        DateTime? updatedAt,
        String? hoursJson}) =>
    Venue(
      id: id,
      name: name,
      category: 'gasthaus',
      latitude: lat,
      longitude: lng,
      priceHalfL: priceHalf,
      verified: false,
      updatedAt: updatedAt,
      openingHoursJson: hoursJson,
    );

void main() {
  final wien = LatLng(48.2082, 16.3738);
  final venues = [
    _venue('a', 'zum Adler',
        lat: 48.21, lng: 16.37, priceHalf: 5.10,
        updatedAt: DateTime(2026, 8, 1)),
    _venue('b', 'Bierstube Graz',
        lat: 47.07, lng: 15.44, priceHalf: 3.90,
        updatedAt: DateTime(2026, 8, 12)),
    _venue('c', 'Craft Corner', updatedAt: null), // ohne Position/Preis
  ];

  test('A–Z sortiert case-insensitive', () {
    final sorted = sortVenues(venues, VenueSort.alphabetical);
    expect(sorted.map((v) => v.id), ['b', 'c', 'a']);
  });

  test('Nähe: näheres zuerst, ohne Koordinaten ans Ende', () {
    final sorted = sortVenues(venues, VenueSort.distance, here: wien);
    expect(sorted.map((v) => v.id), ['a', 'b', 'c']);
    expect(venueDistanceKm(sorted.first, wien), lessThan(1.0));
    expect(venueDistanceKm(sorted.last, wien), isNull);
  });

  test('Preis: günstigstes 0,5 l zuerst, ohne Preis ans Ende', () {
    final sorted = sortVenues(venues, VenueSort.price);
    expect(sorted.map((v) => v.id), ['b', 'a', 'c']);
  });

  test('Aktuell: zuletzt gepflegte zuerst, ohne Zeitstempel ans Ende', () {
    final sorted = sortVenues(venues, VenueSort.updated);
    expect(sorted.map((v) => v.id), ['b', 'a', 'c']);
  });

  test('„Jetzt geöffnet" filtert auf strukturierte Zeiten', () {
    final list = [
      // Mi 11–24 → um Mi 12:00 offen.
      _venue('offen', 'Offenes Wirtshaus',
          hoursJson: '[{"d":3,"von":"11:00","bis":"24:00"}]'),
      // Nur Sa geöffnet.
      _venue('zu', 'Samstagsbeisl',
          hoursJson: '[{"d":6,"von":"10:00","bis":"02:00"}]'),
      // Ohne strukturierte Zeiten: fällt bei aktivem Filter raus.
      _venue('freitext', 'Nur-Freitext-Gasthaus'),
    ];
    final mittwochMittag = DateTime(2026, 8, 12, 12, 0);
    expect(openNow(list, mittwochMittag).map((v) => v.id), ['offen']);
  });
}
