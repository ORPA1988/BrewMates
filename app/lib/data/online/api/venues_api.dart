/// Gasthaeuser der gemeinsamen Datenbank.
///
/// Teil der Aufteilung von `online_service.dart` (Backlog B-3). Der
/// Einstieg bleibt `OnlineService`; diese Klasse hängt dort als Feld
/// `venues`.
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'online_api.dart';

class VenuesApi extends OnlineApi {
  const VenuesApi(super.client, super.nutzer);

  // --------------------------------------------------------------------------
  // Gasthäuser (gemeinsame Datenbank, Migration 0011). Online-first:
  // Supabase ist die Wahrheit, die App hält einen Drift-Cache für Karte,
  // Picker und Offline-Anzeige.
  // --------------------------------------------------------------------------

  static const _venueCols =
      'id, name, category, address, city, latitude, longitude, '
      'opening_hours, opening_hours_json, price_half_l, price_third_l, '
      'verified, created_by, updated_at';

  /// Venues seit [since] (Delta über updated_at); null = offline/abgemeldet.
  Future<List<Map<String, dynamic>>?> fetchVenues({DateTime? since}) async {
    if (currentUser == null) return null;
    try {
      var query = client.from('venues').select(_venueCols);
      if (since != null) {
        query = query.gt('updated_at', since.toUtc().toIso8601String());
      }
      final rows = await query.order('updated_at', ascending: true).limit(500);
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Legt ein Gasthaus an. Rückgabe: (venueId, Fehlermeldung) – genau eines
  /// von beiden ist gesetzt.
  Future<(String?, String?)> createVenue({
    required String name,
    required String category,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    String? openingHours,

    /// Dekodierte JSON-Liste `[{"d":…,"von":…,"bis":…}]` oder null.
    Object? openingHoursJson,
    double? priceHalfL,
    double? priceThirdL,
  }) async {
    final me = currentUser;
    if (me == null) return (null, 'Nicht angemeldet.');
    try {
      final row = await client
          .from('venues')
          .insert({
            'name': name.trim(),
            'category': category,
            'address': _emptyToNull(address),
            'city': _emptyToNull(city),
            'latitude': latitude,
            'longitude': longitude,
            'opening_hours': _emptyToNull(openingHours),
            'opening_hours_json': openingHoursJson,
            'price_half_l': priceHalfL,
            'price_third_l': priceThirdL,
            'created_by': me.id,
          })
          .select('id')
          .single();
      return (row['id'] as String, null);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return (null, 'Dieses Gasthaus gibt es in dem Ort schon.');
      }
      return (null, 'Anlegen fehlgeschlagen.');
    } catch (_) {
      return (null, 'Keine Verbindung – Gasthaus-Pflege braucht Internet.');
    }
  }

  /// Aktualisiert Felder eines Gasthauses; RLS entscheidet, ob erlaubt.
  Future<String?> updateVenue(String id, Map<String, dynamic> patch) async {
    if (currentUser == null) return 'Nicht angemeldet.';
    try {
      await client.from('venues').update(patch).eq('id', id);
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        return 'Dafür reicht deine Vertrauensstufe noch nicht.';
      }
      if (e.code == '23505') {
        return 'Dieses Gasthaus gibt es in dem Ort schon.';
      }
      return 'Speichern fehlgeschlagen.';
    } catch (_) {
      return 'Keine Verbindung – Gasthaus-Pflege braucht Internet.';
    }
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
