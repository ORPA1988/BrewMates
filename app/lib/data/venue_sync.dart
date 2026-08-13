import 'package:drift/drift.dart';

import 'db/database.dart';
import 'online/online_service.dart';

/// Zieht die gemeinsame Gasthaus-Datenbank aus Supabase in den lokalen
/// Drift-Cache. Delta-Sync über `updated_at` (jüngster bekannter Stand),
/// idempotent per Upsert – Karte und Picker arbeiten danach offline.
class VenueSync {
  VenueSync(this.db);

  final AppDatabase db;

  /// Gleicht den Cache ab. Rückgabe: Anzahl übernommener Zeilen
  /// (0 = nichts Neues oder offline).
  Future<int> sync(OnlineService online) async {
    final since = await db.latestVenueUpdate();
    final rows = await online.fetchVenues(since: since);
    if (rows == null || rows.isEmpty) return 0;
    await db.upsertVenues([for (final r in rows) companionFromRow(r)]);
    return rows.length;
  }

  /// Supabase-Zeile → Drift-Companion. Statisch und pur (testbar).
  static VenuesCompanion companionFromRow(Map<String, dynamic> r) =>
      VenuesCompanion(
        id: Value(r['id'] as String),
        name: Value(r['name'] as String),
        category: Value((r['category'] as String?) ?? 'gasthaus'),
        address: Value(r['address'] as String?),
        city: Value(r['city'] as String?),
        latitude: Value((r['latitude'] as num?)?.toDouble()),
        longitude: Value((r['longitude'] as num?)?.toDouble()),
        openingHours: Value(r['opening_hours'] as String?),
        priceHalfL: Value((r['price_half_l'] as num?)?.toDouble()),
        priceThirdL: Value((r['price_third_l'] as num?)?.toDouble()),
        verified: Value((r['verified'] as bool?) ?? false),
        createdBy: Value(r['created_by'] as String?),
        updatedAt: Value(r['updated_at'] == null
            ? null
            : DateTime.parse(r['updated_at'] as String).toUtc()),
      );
}

/// Kategorie → Emoji (Picker, Karte, Schnellansicht).
String venueCategoryEmoji(String category) => switch (category) {
      'biergarten' => '🌳',
      'bar' => '🍸',
      'brauereigasthof' => '🏭',
      'restaurant' => '🍽',
      'club' => '🪩',
      _ => '🍺',
    };

/// Kategorie → deutsches Label.
String venueCategoryLabel(String category) => switch (category) {
      'biergarten' => 'Biergarten',
      'bar' => 'Bar',
      'brauereigasthof' => 'Brauereigasthof',
      'restaurant' => 'Restaurant',
      'club' => 'Club',
      'sonstiges' => 'Sonstiges',
      _ => 'Gasthaus',
    };

const List<String> venueCategories = [
  'gasthaus',
  'biergarten',
  'bar',
  'brauereigasthof',
  'restaurant',
  'club',
  'sonstiges',
];
