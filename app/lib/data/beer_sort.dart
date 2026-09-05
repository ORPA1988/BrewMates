/// Sortierungen für Bier- und Brauereilisten in Entdecken.
///
/// Eigene Datei statt Anbau an `venue_open.dart`: Die Kriterien haben
/// nichts miteinander zu tun (ein Bier hat keinen Preis pro halbem
/// Liter, ein Gasthaus keinen Alkoholgehalt), und neue Funktionen
/// bekommen eigene Dateien statt in Sammelstellen hineinzuwachsen.
///
/// Aufbau und Regeln folgen `sortVenues`: reine Funktionen ohne
/// Widgets, Nullwerte ans Ende, Name als Zweitschlüssel.
library;

import 'package:latlong2/latlong.dart';
import 'db/database.dart';

/// Kriterien für die Bierliste.
enum BeerSort { alphabetical, distance, abv, style }

/// Kriterien für die Brauereiliste. Weniger als bei Bieren — mehr gibt
/// eine Brauereizeile nicht her.
enum BrewerySort { distance, alphabetical }

String beerSortLabel(BeerSort s) => switch (s) {
      BeerSort.alphabetical => 'A–Z',
      BeerSort.distance => '📍 Nähe',
      BeerSort.abv => '% Alkohol',
      BeerSort.style => 'Sorte',
    };

String brewerySortLabel(BrewerySort s) => switch (s) {
      BrewerySort.distance => '📍 Nähe',
      BrewerySort.alphabetical => 'A–Z',
    };

/// Entfernung zur Brauerei in Kilometern, `null` ohne Standort oder
/// ohne Koordinaten.
///
/// **Ein Bier hat keinen Ort.** Es hat eine Brauerei, und die hat einen —
/// deshalb nimmt diese Funktion die Brauerei entgegen, auch wenn sie in
/// der Bierliste benutzt wird.
double? breweryDistanceKm(Brewery b, LatLng? here) {
  if (here == null || b.latitude == null || b.longitude == null) return null;
  return const Distance()(here, LatLng(b.latitude!, b.longitude!)) / 1000.0;
}

/// Sortiert Biere. Einträge ohne den jeweiligen Wert landen am Ende —
/// sie verschwinden nicht: Ein Bier ohne Alkoholangabe ist trotzdem
/// eines.
///
/// Bei gleichem Rang entscheidet der Name. Ohne diesen Zweitschlüssel
/// springt die Liste bei jedem Neuzeichnen: `sort` ist in Dart nicht
/// stabil.
List<BeerWithBrewery> sortBeers(
  List<BeerWithBrewery> beers,
  BeerSort sort, {
  LatLng? here,
}) {
  final sorted = [...beers];
  int nachName(BeerWithBrewery a, BeerWithBrewery b) =>
      a.beer.name.toLowerCase().compareTo(b.beer.name.toLowerCase());

  switch (sort) {
    case BeerSort.alphabetical:
      sorted.sort(nachName);
    case BeerSort.distance:
      sorted.sort((a, b) {
        final c = _nullsLast(breweryDistanceKm(a.brewery, here),
            breweryDistanceKm(b.brewery, here));
        return c != 0 ? c : nachName(a, b);
      });
    case BeerSort.abv:
      // Aufsteigend: Wer nach Alkohol sortiert, sucht meistens das
      // leichtere Glas — nicht das schwerste.
      sorted.sort((a, b) {
        final c = _nullsLast(a.beer.abv, b.beer.abv);
        return c != 0 ? c : nachName(a, b);
      });
    case BeerSort.style:
      sorted.sort((a, b) {
        final c =
            a.beer.style.toLowerCase().compareTo(b.beer.style.toLowerCase());
        return c != 0 ? c : nachName(a, b);
      });
  }
  return sorted;
}

/// Sortiert Brauereien. Ohne Koordinaten ans Ende, wie bei den Bieren.
List<Brewery> sortBreweries(
  List<Brewery> breweries,
  BrewerySort sort, {
  LatLng? here,
}) {
  final sorted = [...breweries];
  int nachName(Brewery a, Brewery b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  switch (sort) {
    case BrewerySort.alphabetical:
      sorted.sort(nachName);
    case BrewerySort.distance:
      sorted.sort((a, b) {
        final c = _nullsLast(
            breweryDistanceKm(a, here), breweryDistanceKm(b, here));
        return c != 0 ? c : nachName(a, b);
      });
  }
  return sorted;
}

int _nullsLast<T extends Comparable<Object>>(T? a, T? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
