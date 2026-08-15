import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/format.dart';
import 'package:brewmates/core/serving_style.dart';
import 'package:brewmates/domain/statistics.dart';

/// Reine Auswertung — ohne Flutter, ohne Datenbank.
///
/// Dass dieser Test `data/` nicht mehr importiert, ist kein Zufall,
/// sondern der Beleg: Die Auswertung hängt an keiner Drift-Zeile mehr,
/// sondern an [StatsEntry]. Kommt hier je wieder ein Import aus `data/`
/// dazu, ist die Schichtregel erneut gebrochen.
void main() {
  final now = DateTime(2026, 8, 15, 20);

  StatsEntry detail({
    required String id,
    required DateTime at,
    String style = 'Märzen',
    String country = 'AT',
    int? volumeMl,
    ServingStyle? serving,
    double? rating,
    bool alcoholFree = false,
    String? venueName,
    String breweryName = 'Stiegl',
  }) =>
      StatsEntry(
        createdAt: at,
        beerId: 'beer-$id',
        beerStyle: style,
        isAlcoholFree: alcoholFree,
        breweryId: 'b1',
        breweryName: breweryName,
        breweryCountry: country,
        venueName: venueName,
        volumeMl: volumeMl,
        serving: serving,
        rating: rating,
      );

  test('Leere Eingabe ergibt eine leere Auswertung', () {
    final stats = computeStats(const [], now: now);
    expect(stats.isEmpty, isTrue);
    expect(stats.totalMl, 0);
    expect(stats.averageRating, isNull);
  });

  test('Gemessene Mengen werden summiert, nichts geschätzt', () {
    final stats = computeStats([
      detail(id: '1', at: now, volumeMl: 500),
      detail(id: '2', at: now, volumeMl: 330),
    ], now: now);

    expect(stats.totalMl, 830);
    expect(stats.estimatedCount, 0);
    expect(stats.volumeIsRough, isFalse);
  });

  test('Fehlende Menge wird nach Gebinde geschätzt und ausgewiesen', () {
    // Alte Check-ins haben keine Menge. Sie wegzulassen würde die Zahl
    // ohne Vorwarnung zu klein machen; sie als gemessen auszugeben wäre
    // eine Lüge. Also: schätzen und dazusagen.
    final stats = computeStats([
      detail(id: '1', at: now, serving: ServingStyle.growler),
      detail(id: '2', at: now, serving: ServingStyle.bottle),
      detail(id: '3', at: now), // gar keine Angabe
    ], now: now);

    expect(stats.totalMl, 1000 + 500 + defaultVolumeMl);
    expect(stats.estimatedCount, 3);
    expect(stats.volumeIsRough, isTrue);
  });

  test('Gemessenes schlägt die Schätzung', () {
    final stats = computeStats([
      detail(id: '1', at: now, serving: ServingStyle.growler, volumeMl: 250),
    ], now: now);

    expect(stats.totalMl, 250);
    expect(stats.estimatedCount, 0);
  });

  test('Zeitraum schneidet Älteres ab', () {
    final rows = [
      detail(id: 'alt', at: DateTime(2025, 5, 1)),
      detail(id: 'jahr', at: DateTime(2026, 2, 1)),
      detail(id: 'monat', at: DateTime(2026, 8, 3)),
    ];

    expect(computeStats(rows, now: now, range: StatsRange.all).checkins, 3);
    expect(computeStats(rows, now: now, range: StatsRange.year).checkins, 2);
    expect(computeStats(rows, now: now, range: StatsRange.month).checkins, 1);
  });

  test('Filter für Land und Stil greifen einzeln und gemeinsam', () {
    final rows = [
      detail(id: '1', at: now, country: 'AT', style: 'Märzen'),
      detail(id: '2', at: now, country: 'DE', style: 'Märzen'),
      detail(id: '3', at: now, country: 'AT', style: 'Pils'),
    ];

    expect(computeStats(rows, now: now, country: 'AT').checkins, 2);
    expect(computeStats(rows, now: now, style: 'Märzen').checkins, 2);
    expect(
        computeStats(rows, now: now, country: 'AT', style: 'Pils').checkins, 1);
    expect(computeStats(rows, now: now, country: 'CH').isEmpty, isTrue);
  });

  test('Aufteilungen zählen richtig, häufigste zuerst', () {
    final stats = computeStats([
      detail(id: '1', at: now, style: 'Märzen'),
      detail(id: '2', at: now, style: 'Märzen'),
      detail(id: '3', at: now, style: 'Pils'),
    ], now: now);

    expect(stats.byStyle.first.label, 'Märzen');
    expect(stats.byStyle.first.count, 2);
    expect(stats.byStyle.last.label, 'Pils');
  });

  test('Gleichstand wird alphabetisch aufgelöst (stabile Reihenfolge)', () {
    final stats = computeStats([
      detail(id: '1', at: now, style: 'Zwickl'),
      detail(id: '2', at: now, style: 'Alt'),
    ], now: now);

    expect(stats.byStyle.map((s) => s.label).toList(), ['Alt', 'Zwickl']);
  });

  test('Verschiedene Biere, Brauereien und Orte werden einzeln gezählt', () {
    final stats = computeStats([
      detail(id: '1', at: now, venueName: 'Augustiner'),
      detail(id: '2', at: now, venueName: 'Augustiner'),
      detail(id: '3', at: now), // ohne Ort
    ], now: now);

    expect(stats.checkins, 3);
    expect(stats.distinctBeers, 3);
    expect(stats.distinctBreweries, 1);
    // Ohne Ort zählt nicht mit, doppelte Orte nur einmal.
    expect(stats.distinctVenues, 1);
  });

  test('Ohne Angabe erscheint als eigenes Gebinde statt zu verschwinden', () {
    final stats = computeStats([
      detail(id: '1', at: now, serving: ServingStyle.draft),
      detail(id: '2', at: now),
    ], now: now);

    final labels = stats.byServing.map((s) => s.label).toList();
    expect(labels, containsAll(['vom Fass', 'ohne Angabe']));
  });

  test('Durchschnitt rechnet nur über bewertete Check-ins', () {
    final stats = computeStats([
      detail(id: '1', at: now, rating: 4),
      detail(id: '2', at: now, rating: 3),
      detail(id: '3', at: now), // unbewertet zieht nicht nach unten
    ], now: now);

    expect(stats.averageRating, 3.5);
  });

  test('Monate erscheinen aufsteigend und nur, wenn es sie gibt', () {
    final stats = computeStats([
      detail(id: '1', at: DateTime(2026, 8, 2)),
      detail(id: '2', at: DateTime(2026, 6, 9)),
      detail(id: '3', at: DateTime(2026, 8, 30)),
    ], now: now);

    // Juli fehlt bewusst: kein Eintrag ist kein Nullwert.
    expect(stats.byMonth.map((s) => s.label).toList(), ['06/2026', '08/2026']);
    expect(stats.byMonth.last.count, 2);
  });

  test('Alkoholfreie werden mitgezählt', () {
    final stats = computeStats([
      detail(id: '1', at: now, alcoholFree: true),
      detail(id: '2', at: now),
    ], now: now);

    expect(stats.alcoholFree, 1);
  });

  group('Formatierung', () {
    test('Füllmengen in deutscher Schreibweise', () {
      expect(formatVolume(330), '0,33 l');
      expect(formatVolume(500), '0,5 l');
      expect(formatVolume(1000), '1 l');
      expect(formatVolume(250), '0,25 l');
    });

    test('Liter mit einer Nachkommastelle', () {
      expect(formatLitres(12.44), '12,4 l');
      expect(formatLitres(0), '0,0 l');
    });
  });
}
