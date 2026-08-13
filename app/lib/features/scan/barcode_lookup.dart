import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/db/database.dart';

/// Ergebnis der Barcode-Suche (Reihenfolge: lokale DB → Open Food Facts).
sealed class BarcodeLookupResult {
  const BarcodeLookupResult();
}

/// Bier ist in der lokalen/Community-Datenbank → direkt einchecken.
class LocalBeerFound extends BarcodeLookupResult {
  const LocalBeerFound(this.beer);

  final BeerWithBrewery beer;
}

/// Produkt bei Open Food Facts gefunden → Anlegen-Formular vorbefüllen.
class OffProductFound extends BarcodeLookupResult {
  const OffProductFound({required this.ean, this.name, this.brand});

  final String ean;
  final String? name;
  final String? brand;
}

/// Nirgends bekannt → leeres Anlegen-Formular mit EAN.
class BarcodeUnknown extends BarcodeLookupResult {
  const BarcodeUnknown(this.ean);

  final String ean;
}

/// Pure Lookup-Logik, getrennt von der Scanner-UI (testbar ohne Kamera).
class BarcodeLookup {
  BarcodeLookup(this.db, {http.Client? client})
      : _client = client ?? http.Client();

  final AppDatabase db;
  final http.Client _client;

  static const _offBase = 'https://world.openfoodfacts.org/api/v2/product';
  static const userAgent = 'BrewMates/1.2 (github.com/ORPA1988/BrewMates)';

  /// Gültige EANs haben 8 oder 13 Ziffern.
  static bool isValidEan(String input) =>
      RegExp(r'^\d{8}$|^\d{13}$').hasMatch(input);

  Future<BarcodeLookupResult> lookup(String ean) async {
    final local = await db.findBeerByBarcode(ean);
    if (local != null) return LocalBeerFound(local);

    try {
      final response = await _client.get(
        Uri.parse('$_offBase/$ean.json?fields=code,product_name,brands'),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (data['status'] == 1) {
          final product = data['product'] as Map<String, dynamic>? ?? {};
          final name = (product['product_name'] as String?)?.trim();
          final brand =
              (product['brands'] as String?)?.split(',').first.trim();
          return OffProductFound(
            ean: ean,
            name: (name?.isEmpty ?? true) ? null : name,
            brand: (brand?.isEmpty ?? true) ? null : brand,
          );
        }
      }
    } catch (_) {
      // Offline oder Zeitüberschreitung – kein Fehler, nur „unbekannt".
    }
    return BarcodeUnknown(ean);
  }
}
