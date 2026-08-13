import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'db/database.dart';

/// Synchronisiert die redaktionelle Community-Datenbank (Biere & Brauereien
/// aus Österreich und Bayern) in die lokale DB.
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

  /// Regionen-Dateipaare (Brauereien, Biere) – Reihenfolge: Brauereien
  /// zuerst, damit die Fremdschlüssel der Biere immer auflösbar sind.
  static const breweryFiles = ['breweries-at.json', 'breweries-by.json'];
  static const beerFiles = ['beers-at.json', 'beers-by.json'];

  static const beersAsset = 'assets/data/beers-at.json';
  static const breweriesAsset = 'assets/data/breweries-at.json';

  /// Import der gebündelten Dateien (offline, erste Installation).
  /// `cache: false`: der Future-Cache von rootBundle kann in Widget-Tests
  /// ein nie fertig werdendes Future aus einer früheren Test-Zone liefern.
  Future<int> importBundledData() async {
    var imported = 0;
    for (final file in breweryFiles) {
      final jsonString = await _loadAsset('assets/data/$file');
      if (jsonString == null) continue;
      final rows = parseBreweries(jsonString);
      await db.upsertCommunityData(breweryRows: rows, beerRows: const []);
      imported += rows.length;
    }
    for (final file in beerFiles) {
      final jsonString = await _loadAsset('assets/data/$file');
      if (jsonString == null) continue;
      final rows = parseBeers(jsonString);
      await db.upsertCommunityData(breweryRows: const [], beerRows: rows);
      imported += rows.length;
    }
    return imported;
  }

  Future<String?> _loadAsset(String asset) async {
    try {
      // Bewusst load() + eigenes Dekodieren statt loadString(): loadString
      // lagert Assets über 50 KiB zum Dekodieren in einen Isolate aus,
      // dessen Antwort in Widget-Tests nie eintrifft – der Import hinge
      // dann für immer. Die JSON-Dateien sind klein genug, um sie direkt
      // auf dem UI-Isolate zu dekodieren.
      final data = await rootBundle.load(asset);
      return utf8.decode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {
      // Asset fehlt (z. B. in Unit-Tests ohne Binding) – kein Fehler.
      return null;
    }
  }

  /// Neueste Fassung von GitHub laden. Gibt die Anzahl importierter
  /// Einträge zurück; wirft bei Netzwerkfehlern eine Exception.
  /// Fehlt eine einzelne Datei auf GitHub (404, z. B. neue Region noch
  /// nicht gemergt), wird sie übersprungen statt den Sync abzubrechen.
  Future<int> syncFromGitHub() async {
    var imported = 0;
    var fetched = 0;
    for (final file in breweryFiles) {
      final body = await _fetch(file);
      if (body == null) continue;
      final rows = parseBreweries(body);
      await db.upsertCommunityData(breweryRows: rows, beerRows: const []);
      imported += rows.length;
      fetched++;
    }
    for (final file in beerFiles) {
      final body = await _fetch(file);
      if (body == null) continue;
      final rows = parseBeers(body);
      await db.upsertCommunityData(breweryRows: const [], beerRows: rows);
      imported += rows.length;
      fetched++;
    }
    if (fetched == 0) {
      throw http.ClientException('GitHub-Sync fehlgeschlagen (keine Datei)');
    }
    return imported;
  }

  Future<String?> _fetch(String file) async {
    final res = await _client
        .get(Uri.parse('$_repoRaw/$file'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    return utf8.decode(res.bodyBytes);
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
          barcodes: Value(
              ((b['barcodes'] as List?)?.cast<String>() ?? const [])
                  .join(',')),
          imageUrl: Value(b['image_url'] as String?),
        ),
    ];
  }
}
