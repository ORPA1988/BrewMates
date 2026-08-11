import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'db/database.dart';

/// Synchronisiert die redaktionelle Community-Datenbank (österreichische
/// Biere & Brauereien) in die lokale DB.
///
/// Quellen, in dieser Reihenfolge:
/// 1. Gebündelte Assets (`assets/data/*.json`) – funktioniert offline,
///    wird beim ersten Start importiert.
/// 2. GitHub (raw.githubusercontent.com, main-Branch) – holt beim App-Start
///    und auf Knopfdruck die neueste Fassung derselben Dateien.
///
/// Nutzerdaten (Check-ins, Bewertungen, Sessions …) sind davon unberührt
/// und bleiben ausschließlich lokal.
class CommunitySync {
  CommunitySync(this.db, {http.Client? client})
      : _client = client ?? http.Client();

  final AppDatabase db;
  final http.Client _client;

  static const _repoRaw =
      'https://raw.githubusercontent.com/ORPA1988/BrewMates/main/app/assets/data';
  static const beersAsset = 'assets/data/beers-at.json';
  static const breweriesAsset = 'assets/data/breweries-at.json';

  /// Import der gebündelten Dateien (offline, erste Installation).
  Future<int> importBundledData() async {
    try {
      final breweriesJson = await rootBundle.loadString(breweriesAsset);
      final beersJson = await rootBundle.loadString(beersAsset);
      return await _importJson(breweriesJson, beersJson);
    } catch (_) {
      // Assets fehlen (z. B. in Unit-Tests ohne Binding) – kein Fehler.
      return 0;
    }
  }

  /// Neueste Fassung von GitHub laden. Gibt die Anzahl importierter
  /// Einträge zurück; wirft bei Netzwerkfehlern eine Exception.
  Future<int> syncFromGitHub() async {
    final breweriesRes =
        await _client.get(Uri.parse('$_repoRaw/breweries-at.json'));
    final beersRes = await _client.get(Uri.parse('$_repoRaw/beers-at.json'));
    if (breweriesRes.statusCode != 200 || beersRes.statusCode != 200) {
      throw http.ClientException(
          'GitHub-Sync fehlgeschlagen (${breweriesRes.statusCode}/${beersRes.statusCode})');
    }
    return _importJson(
        utf8.decode(breweriesRes.bodyBytes), utf8.decode(beersRes.bodyBytes));
  }

  /// Wie [syncFromGitHub], aber still: bei fehlender Verbindung passiert
  /// nichts (für den automatischen Abgleich beim App-Start).
  Future<void> syncSilently() async {
    try {
      await syncFromGitHub();
    } catch (_) {
      // offline – gebündelte/lokale Daten bleiben gültig.
    }
  }

  Future<int> _importJson(String breweriesJson, String beersJson) async {
    final breweryRows = parseBreweries(breweriesJson);
    final beerRows = parseBeers(beersJson);
    await db.upsertCommunityData(
        breweryRows: breweryRows, beerRows: beerRows);
    return breweryRows.length + beerRows.length;
  }

  static List<BreweriesCompanion> parseBreweries(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final list = (data['breweries'] as List).cast<Map<String, dynamic>>();
    return [
      for (final b in list)
        BreweriesCompanion.insert(
          id: b['id'] as String,
          name: b['name'] as String,
          country: (b['country'] as String?) ?? 'Österreich',
          city: (b['city'] as String?) ?? '',
          address: Value(b['address'] as String?),
          latitude: Value((b['latitude'] as num?)?.toDouble()),
          longitude: Value((b['longitude'] as num?)?.toDouble()),
          founded: Value((b['founded'] as num?)?.toInt()),
          website: Value(b['website'] as String?),
          ownership: Value(b['ownership'] as String?),
          employees: Value((b['employees'] as num?)?.toInt()),
          annualOutputHl: Value((b['annual_output_hl'] as num?)?.toInt()),
          revenueEur: Value((b['revenue_eur'] as num?)?.toInt()),
          notes: Value(b['notes'] as String?),
          dataStatus: Value(b['data_status'] as String?),
        ),
    ];
  }

  static List<BeersCompanion> parseBeers(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final list = (data['beers'] as List).cast<Map<String, dynamic>>();
    return [
      for (final b in list)
        BeersCompanion.insert(
          id: b['id'] as String,
          breweryId: b['brewery_id'] as String,
          name: b['name'] as String,
          style: b['style'] as String,
          abv: Value((b['abv'] as num?)?.toDouble()),
          ibu: Value((b['ibu'] as num?)?.toInt()),
          isAlcoholFree: Value((b['is_alcohol_free'] as bool?) ?? false),
          description: Value(b['description_manufacturer'] as String?),
          descriptionCommunity: Value(b['description_community'] as String?),
          communityRating: Value((b['community_rating'] as num?)?.toDouble()),
        ),
    ];
  }
}
