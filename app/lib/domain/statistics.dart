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

import '../data/db/database.dart';

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
int volumeMlOf(Checkin c) =>
    c.volumeMl ??
    (c.servingStyle == null
        ? defaultVolumeMl
        : estimatedVolumeMl[c.servingStyle] ?? defaultVolumeMl);

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
  List<CheckinDetails> all, {
  required DateTime now,
  StatsRange range = StatsRange.all,
  String? country,
  String? style,
}) {
  final from = range.startFrom(now);
  final rows = [
    for (final d in all)
      if ((from == null || !d.checkin.createdAt.isBefore(from)) &&
          (country == null || d.brewery.country == country) &&
          (style == null || d.beer.style == style))
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
    totalMl += volumeMlOf(d.checkin);
    if (d.checkin.volumeMl == null) estimated++;
    final r = d.checkin.rating;
    if (r != null) {
      ratingSum += r;
      ratingCount++;
    }
    if (d.beer.isAlcoholFree) alcoholFree++;
  }

  // Monate lückenlos wäre schöner, aber irreführend: Ein Monat ohne
  // Check-in ist kein Nullwert, sondern ein Monat ohne Eintrag.
  final monthCounts = <String, int>{};
  for (final d in rows) {
    final c = d.checkin.createdAt;
    final key = '${c.year}-${c.month.toString().padLeft(2, '0')}';
    monthCounts[key] = (monthCounts[key] ?? 0) + 1;
  }
  final months = monthCounts.keys.toList()..sort();

  return CheckinStats(
    checkins: rows.length,
    distinctBeers: {for (final d in rows) d.beer.id}.length,
    distinctBreweries: {for (final d in rows) d.brewery.id}.length,
    distinctVenues: {
      for (final d in rows)
        if (d.checkin.venueName != null) d.checkin.venueName!,
    }.length,
    totalMl: totalMl,
    estimatedCount: estimated,
    byCountry: _tally([for (final d in rows) d.brewery.country]),
    byStyle: _tally([for (final d in rows) d.beer.style], top: 10),
    byServing:
        _tally([for (final d in rows) _servingLabel(d.checkin.servingStyle)]),
    byBrewery: _tally([for (final d in rows) d.brewery.name], top: 10),
    byMonth: [
      for (final m in months)
        StatSlice('${m.substring(5)}/${m.substring(0, 4)}', monthCounts[m]!),
    ],
    averageRating: ratingCount == 0 ? null : ratingSum / ratingCount,
    alcoholFree: alcoholFree,
  );
}
