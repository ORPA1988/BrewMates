/// Auswertung der eigenen Check-ins.
///
/// Bewusst ohne Flutter und ohne Datenbank: Die Funktionen bekommen eine
/// Liste und geben Zahlen zurück. Das macht sie vollständig testbar — und
/// erlaubt es später, die Summenbildung nach SQL zu verlagern, ohne die
/// Darstellung anzufassen.
///
/// **Grundsatz:** Ausgewertet wird Vielfalt und Erinnerung, nicht
/// Leistung. Liter erscheinen, weil die Frage naheliegt — nie als
/// Rangliste gegen andere und nie mit einer Zielvorgabe.
library;

import '../core/serving_style.dart';

/// Geschätzte Füllmenge je Gebinde, wenn der Check-in keine Angabe hat.
///
/// Alle Check-ins vor 0.9.15 haben keine. Sie deshalb aus der
/// Literauswertung zu werfen, würde die Zahl ohne Vorwarnung zu klein
/// machen; sie mitzuzählen, als wären sie gemessen, wäre eine Lüge.
/// Deshalb: schätzen **und** ausweisen, wie viele geschätzt sind.
const Map<ServingStyle, int> estimatedVolumeMl = {
  ServingStyle.draft: 500,
  ServingStyle.bottle: 500,
  ServingStyle.can: 500,
  ServingStyle.growler: 1000,
};

/// Ein Check-in, reduziert auf das, was die Auswertung braucht.
///
/// Der Grund für diesen Typ ist die Schichtregel: `domain/` kennt die
/// Datenbank nicht. Er hat aber einen zweiten Nutzen — die Auswertung
/// lässt sich ohne Drift-Objekte testen, und wenn die Summenbildung
/// eines Tages nach SQL wandert, liefert die Abfrage einfach diese
/// Felder statt ganzer Zeilen.
class StatsEntry {
  const StatsEntry({
    required this.createdAt,
    required this.beerId,
    required this.beerStyle,
    required this.isAlcoholFree,
    required this.breweryId,
    required this.breweryName,
    required this.breweryCountry,
    this.venueName,
    this.volumeMl,
    this.serving,
    this.rating,
  });

  final DateTime createdAt;

  final String beerId;
  final String beerStyle;
  final bool isAlcoholFree;

  final String breweryId;
  final String breweryName;
  final String breweryCountry;

  /// Name des Gasthauses, wenn der Check-in einem zugeordnet ist.
  final String? venueName;

  /// Gemessene Menge; `null` heißt „nicht erfasst" und wird geschätzt.
  final int? volumeMl;

  final ServingStyle? serving;

  final double? rating;
}

/// Fallback, wenn nicht einmal das Gebinde bekannt ist.
const int defaultVolumeMl = 500;

/// Zeitraum der Auswertung.
enum StatsRange { month, year, all }

extension StatsRangeLabel on StatsRange {
  String get label => switch (this) {
        StatsRange.month => 'Dieser Monat',
        StatsRange.year => 'Dieses Jahr',
        StatsRange.all => 'Alles',
      };

  /// Frühester Zeitpunkt, der noch zählt (null = keine Grenze).
  DateTime? startFrom(DateTime now) => switch (this) {
        StatsRange.month => DateTime(now.year, now.month),
        StatsRange.year => DateTime(now.year),
        StatsRange.all => null,
      };
}

/// Ein Balken in einer Aufteilung.
class StatSlice {
  const StatSlice(this.label, this.count);

  final String label;
  final int count;
}

/// Das Ergebnis einer Auswertung.
class CheckinStats {
  const CheckinStats({
    required this.checkins,
    required this.distinctBeers,
    required this.distinctBreweries,
    required this.distinctVenues,
    required this.totalMl,
    required this.estimatedCount,
    required this.byCountry,
    required this.byStyle,
    required this.byServing,
    required this.byBrewery,
    required this.byMonth,
    required this.averageRating,
    required this.alcoholFree,
  });

  final int checkins;
  final int distinctBeers;
  final int distinctBreweries;
  final int distinctVenues;

  /// Gesamtmenge in Millilitern, inklusive geschätzter Anteile.
  final int totalMl;

  /// Wie viele Check-ins dabei geschätzt wurden — die Anzeige sagt es dazu.
  final int estimatedCount;

  final List<StatSlice> byCountry;
  final List<StatSlice> byStyle;
  final List<StatSlice> byServing;
  final List<StatSlice> byBrewery;

  /// Check-ins je Monat, älteste zuerst (Beschriftung „08/2026").
  final List<StatSlice> byMonth;

  /// Durchschnittsbewertung über die bewerteten Check-ins (null = keine).
  final double? averageRating;

  final int alcoholFree;

  bool get isEmpty => checkins == 0;

  /// Gesamtmenge in Litern.
  double get totalLitres => totalMl / 1000;

  /// Ist ein nennenswerter Teil der Menge geschätzt?
  bool get volumeIsRough => estimatedCount > 0;
}

/// Menge eines einzelnen Check-ins — gemessen, sonst nach Gebinde
/// geschätzt.
int volumeMlOf(StatsEntry e) =>
    e.volumeMl ??
    (e.serving == null
        ? defaultVolumeMl
        : estimatedVolumeMl[e.serving] ?? defaultVolumeMl);

String _servingLabel(ServingStyle? s) => switch (s) {
      ServingStyle.draft => 'vom Fass',
      ServingStyle.bottle => 'Flasche',
      ServingStyle.can => 'Dose',
      ServingStyle.growler => 'Growler',
      null => 'ohne Angabe',
    };

/// Zählt [values] und gibt die häufigsten zuerst zurück.
List<StatSlice> _tally(Iterable<String> values, {int? top}) {
  final counts = <String, int>{};
  for (final v in values) {
    if (v.trim().isEmpty) continue;
    counts[v] = (counts[v] ?? 0) + 1;
  }
  final slices = [
    for (final e in counts.entries) StatSlice(e.key, e.value),
  ]..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      // Bei Gleichstand alphabetisch — sonst springt die Reihenfolge
      // zwischen zwei Aufrufen.
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });
  return top == null || slices.length <= top
      ? slices
      : slices.sublist(0, top);
}

/// Wertet [all] aus, eingeschränkt auf [range] (gerechnet ab [now]) und
/// optional auf ein Land bzw. einen Stil.
CheckinStats computeStats(
  List<StatsEntry> all, {
  required DateTime now,
  StatsRange range = StatsRange.all,
  String? country,
  String? style,
}) {
  final from = range.startFrom(now);
  final rows = [
    for (final d in all)
      if ((from == null || !d.createdAt.isBefore(from)) &&
          (country == null || d.breweryCountry == country) &&
          (style == null || d.beerStyle == style))
        d,
  ];

  if (rows.isEmpty) {
    return const CheckinStats(
      checkins: 0,
      distinctBeers: 0,
      distinctBreweries: 0,
      distinctVenues: 0,
      totalMl: 0,
      estimatedCount: 0,
      byCountry: [],
      byStyle: [],
      byServing: [],
      byBrewery: [],
      byMonth: [],
      averageRating: null,
      alcoholFree: 0,
    );
  }

  var totalMl = 0;
  var estimated = 0;
  var ratingSum = 0.0;
  var ratingCount = 0;
  var alcoholFree = 0;
  for (final d in rows) {
    totalMl += volumeMlOf(d);
    if (d.volumeMl == null) estimated++;
    final r = d.rating;
    if (r != null) {
      ratingSum += r;
      ratingCount++;
    }
    if (d.isAlcoholFree) alcoholFree++;
  }

  // Monate lückenlos wäre schöner, aber irreführend: Ein Monat ohne
  // Check-in ist kein Nullwert, sondern ein Monat ohne Eintrag.
  final monthCounts = <String, int>{};
  for (final d in rows) {
    final c = d.createdAt;
    final key = '${c.year}-${c.month.toString().padLeft(2, '0')}';
    monthCounts[key] = (monthCounts[key] ?? 0) + 1;
  }
  final months = monthCounts.keys.toList()..sort();

  return CheckinStats(
    checkins: rows.length,
    distinctBeers: {for (final d in rows) d.beerId}.length,
    distinctBreweries: {for (final d in rows) d.breweryId}.length,
    distinctVenues: {
      for (final d in rows)
        if (d.venueName != null) d.venueName!,
    }.length,
    totalMl: totalMl,
    estimatedCount: estimated,
    byCountry: _tally([for (final d in rows) d.breweryCountry]),
    byStyle: _tally([for (final d in rows) d.beerStyle], top: 10),
    byServing: _tally([for (final d in rows) _servingLabel(d.serving)]),
    byBrewery: _tally([for (final d in rows) d.breweryName], top: 10),
    byMonth: [
      for (final m in months)
        StatSlice('${m.substring(5)}/${m.substring(0, 4)}', monthCounts[m]!),
    ],
    averageRating: ratingCount == 0 ? null : ratingSum / ratingCount,
    alcoholFree: alcoholFree,
  );
}
