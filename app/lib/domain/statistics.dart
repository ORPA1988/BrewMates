/// Auswertung der eigenen Check-ins.
///
/// Bewusst ohne Flutter und ohne Datenbank: Die Funktion bekommt eine
/// Liste und gibt Zahlen zurück. Das macht sie vollständig testbar — und
/// erlaubt es später, die Summenbildung nach SQL zu verlagern, ohne die
/// Darstellung anzufassen.
///
/// **Grundsatz:** Ausgewertet wird Vielfalt und Erinnerung, nicht
/// Leistung. Liter erscheinen, weil die Frage naheliegt — nie als
/// Rangliste gegen andere und nie mit einer Zielvorgabe.
///
/// **Seit 0.10.14 sind Aufteilungen und Kennzahlen Daten**, keine Felder:
/// `statistics/dimensions.dart` und `statistics/measures.dart`. Wer eine
/// neue Auswertung will, trägt sie dort ein — hier ist nichts zu ändern.
library;

import '../core/checkin_facts.dart';
import '../core/serving_style.dart';
import 'statistics/alcohol.dart';
import 'statistics/dimensions.dart';
import 'statistics/measures.dart';

export 'statistics/alcohol.dart';
export 'statistics/dimensions.dart';
export 'statistics/measures.dart';

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

/// Vorgefertigter Zeitraum.
enum StatsRange { month, year, all }

extension StatsRangeLabel on StatsRange {
  String get label => switch (this) {
        StatsRange.month => 'Dieser Monat',
        StatsRange.year => 'Dieses Jahr',
        StatsRange.all => 'Alles',
      };
}

/// Der Zeitraum einer Auswertung — als Wertobjekt, nicht als Enum.
///
/// Der Unterschied trägt: Ein Enum kann „dieser Monat" sagen, aber weder
/// „1.–14. Juli" noch „der Zeitraum davor". Beides braucht die Auswertung
/// (freier Zeitraum, Vergleich zum Vorzeitraum), und beides wäre mit
/// einem Enum eine Sonderbehandlung an jeder Aufrufstelle.
class StatsPeriod {
  const StatsPeriod.preset(StatsRange range)
      : _range = range,
        _from = null,
        _to = null;

  /// Von-bis, jeweils einschließlich des Tages.
  const StatsPeriod.custom(DateTime from, DateTime to)
      : _range = null,
        _from = from,
        _to = to;

  final StatsRange? _range;
  final DateTime? _from;
  final DateTime? _to;

  /// Der vorgefertigte Zeitraum, oder `null` bei einem freien.
  StatsRange? get preset => _range;

  bool get isCustom => _range == null;

  /// Frühester Zeitpunkt, der noch zählt. `null` = keine Grenze.
  DateTime? startAt(DateTime now) => switch (_range) {
        StatsRange.month => DateTime(now.year, now.month),
        StatsRange.year => DateTime(now.year),
        StatsRange.all => null,
        null => DateTime(_from!.year, _from.month, _from.day),
      };

  /// Spätester Zeitpunkt, der noch zählt. `null` = keine Grenze.
  ///
  /// Beim freien Zeitraum ist der Endtag **eingeschlossen** — wer „bis
  /// 14. Juli" wählt, meint den ganzen 14., nicht dessen Mitternacht.
  DateTime? endAt(DateTime now) => _range != null
      ? null
      : DateTime(_to!.year, _to.month, _to.day).add(const Duration(days: 1));

  String get label => switch (_range) {
        StatsRange.month => 'Dieser Monat',
        StatsRange.year => 'Dieses Jahr',
        StatsRange.all => 'Alles',
        null => '${_datum(_from!)} – ${_datum(_to!)}',
      };

  /// Beschriftung des Vergleichszeitraums, für „gegenüber …".
  String get previousLabel => switch (_range) {
        StatsRange.month => 'Vormonat',
        StatsRange.year => 'Vorjahr',
        StatsRange.all => '',
        null => 'davor',
      };

  /// Der gleich lange Zeitraum davor — oder `null`, wenn es keinen gibt.
  ///
  /// „Alles" hat kein Davor. Bei Monat und Jahr ist es der volle
  /// Vormonat bzw. das volle Vorjahr; beim freien Zeitraum die gleiche
  /// Anzahl Tage unmittelbar davor.
  StatsPeriod? previous(DateTime now) => switch (_range) {
        StatsRange.all => null,
        StatsRange.month => StatsPeriod.custom(
            DateTime(now.year, now.month - 1),
            DateTime(now.year, now.month).subtract(const Duration(days: 1)),
          ),
        StatsRange.year => StatsPeriod.custom(
            DateTime(now.year - 1),
            DateTime(now.year).subtract(const Duration(days: 1)),
          ),
        null => () {
            final tage = _to!.difference(_from!).inDays + 1;
            final bis = _from.subtract(const Duration(days: 1));
            return StatsPeriod.custom(
              bis.subtract(Duration(days: tage - 1)),
              bis,
            );
          }(),
      };

  static String _datum(DateTime d) =>
      '${d.day}.${d.month}.${d.year}';
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
    required this.totalMl,
    required this.estimatedCount,
    required this.byDimension,
    required this.values,
    required this.byMonth,
    required this.alcohol,
    this.previous,
  });

  /// Die leere Auswertung — kein Sonderfall im Aufrufer.
  static const empty = CheckinStats(
    checkins: 0,
    totalMl: 0,
    estimatedCount: 0,
    byDimension: {},
    values: {},
    byMonth: [],
    alcohol: AlcoholSummary.empty,
  );

  final int checkins;

  /// Gesamtmenge in Millilitern, inklusive geschätzter Anteile.
  final int totalMl;

  /// Wie viele Check-ins dabei geschätzt wurden — die Anzeige sagt es dazu.
  final int estimatedCount;

  /// Alle Aufteilungen, nach dem Schlüssel aus [dimensions].
  final Map<String, List<StatSlice>> byDimension;

  /// Alle Kennzahlen, nach dem Schlüssel aus [measures]. Enthält nur, was
  /// tatsächlich einen Wert hat — eine fehlende Bewertung steht hier
  /// nicht als 0.
  final Map<String, double> values;

  /// Check-ins je Monat, älteste zuerst (Beschriftung „08/2026").
  ///
  /// Bleibt eine eigene Größe statt einer Aufteilung: Sie ist die
  /// Zeitachse, wird chronologisch statt nach Menge sortiert und anders
  /// dargestellt.
  final List<StatSlice> byMonth;

  /// Reinalkohol im Zeitraum — steht bewusst neben den Kennzahlen statt
  /// unter ihnen, siehe `statistics/alcohol.dart`.
  final AlcoholSummary alcohol;

  /// Dieselbe Auswertung über den Zeitraum davor — für den Maßstab.
  /// `null` bei „Alles" und in der Vergleichsauswertung selbst.
  final CheckinStats? previous;

  bool get isEmpty => checkins == 0;

  /// Gesamtmenge in Litern.
  double get totalLitres => totalMl / 1000;

  /// Ist ein nennenswerter Teil der Menge geschätzt?
  bool get volumeIsRough => estimatedCount > 0;

  /// Die Balken einer Aufteilung; leer, wenn es sie nicht gibt.
  List<StatSlice> slices(String dimensionKey) =>
      byDimension[dimensionKey] ?? const [];

  /// Der Wert einer Kennzahl, oder `null`, wenn sie hier nichts sagt.
  double? value(String measureKey) => values[measureKey];
}

/// Menge eines einzelnen Check-ins — gemessen, sonst nach Gebinde
/// geschätzt.
int volumeMlOf(CheckinFacts e) =>
    e.volumeMl ??
    (e.serving == null
        ? defaultVolumeMl
        : estimatedVolumeMl[e.serving] ?? defaultVolumeMl);

/// Zählt [values] und sortiert: häufigste zuerst, oder nach [fixedOrder].
List<StatSlice> _tally(
  Iterable<String> values, {
  int? top,
  List<String>? fixedOrder,
}) {
  final counts = <String, int>{};
  for (final v in values) {
    if (v.trim().isEmpty) continue;
    counts[v] = (counts[v] ?? 0) + 1;
  }
  final slices = [
    for (final e in counts.entries) StatSlice(e.key, e.value),
  ];

  if (fixedOrder != null) {
    // Werte außerhalb der festen Reihenfolge hinten anhängen, statt sie
    // zu verlieren — eine Aufteilung, die still etwas unterschlägt, ist
    // schlimmer als eine unordentliche.
    slices.sort((a, b) {
      final ia = fixedOrder.indexOf(a.label);
      final ib = fixedOrder.indexOf(b.label);
      if (ia == -1 && ib == -1) return a.label.compareTo(b.label);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
  } else {
    slices.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      // Bei Gleichstand alphabetisch — sonst springt die Reihenfolge
      // zwischen zwei Aufrufen.
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });
  }

  return top == null || slices.length <= top ? slices : slices.sublist(0, top);
}

/// Wertet [all] aus, eingeschränkt auf [period] (gerechnet ab [now]) und
/// optional auf ein Land bzw. einen Stil.
///
/// [withPrevious] steuert nur, ob der Vergleichszeitraum mitgerechnet
/// wird — die Vergleichsauswertung selbst braucht keinen eigenen
/// Vergleich, sonst liefe das endlos.
CheckinStats computeStats(
  List<CheckinFacts> all, {
  required DateTime now,
  StatsPeriod period = const StatsPeriod.preset(StatsRange.all),
  String? country,
  String? style,
  bool withPrevious = true,
}) {
  final from = period.startAt(now);
  final to = period.endAt(now);

  bool imZeitraum(CheckinFacts d) =>
      (from == null || !d.createdAt.isBefore(from)) &&
      (to == null || d.createdAt.isBefore(to));

  final rows = [
    for (final d in all)
      if (imZeitraum(d) &&
          (country == null || d.breweryCountry == country) &&
          (style == null || d.beerStyle == style))
        d,
  ];

  final vorher = withPrevious && period.previous(now) != null
      ? computeStats(
          all,
          now: now,
          period: period.previous(now)!,
          country: country,
          style: style,
          withPrevious: false,
        )
      : null;

  if (rows.isEmpty) {
    // Der Vergleichszeitraum bleibt erhalten: „diesen Monat noch nichts,
    // im Vormonat waren es 12" ist eine Aussage, „nichts" allein nicht.
    return CheckinStats(
      checkins: 0,
      totalMl: 0,
      estimatedCount: 0,
      byDimension: const {},
      values: const {},
      byMonth: const [],
      alcohol: AlcoholSummary.empty,
      previous: vorher,
    );
  }

  var totalMl = 0;
  var estimated = 0;
  for (final d in rows) {
    totalMl += volumeMlOf(d);
    if (d.volumeMl == null) estimated++;
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

  // „Neu" heißt neu — unabhängig davon, welcher Filter gerade gesetzt
  // ist. Deshalb wird hier über `all` gerechnet, nicht über `rows`.
  final earlier = from == null
      ? null
      : {
          for (final d in all)
            if (d.createdAt.isBefore(from)) d.beerId,
        };

  final eingabe = MeasureInput(
    rows: rows,
    earlierBeerIds: earlier,
    weeks: _weeksIn(rows, from, to, now),
    totalMl: totalMl,
  );

  return CheckinStats(
    checkins: rows.length,
    totalMl: totalMl,
    estimatedCount: estimated,
    byDimension: {
      for (final d in dimensions)
        d.key: _tally(
          [
            for (final r in rows)
              if (d.valueOf(r) != null) d.valueOf(r)!,
          ],
          top: d.top,
          fixedOrder: d.fixedOrder,
        ),
    },
    values: {
      for (final m in measures)
        if (m.valueOf(eingabe) != null) m.key: m.valueOf(eingabe)!,
    },
    byMonth: [
      for (final m in months)
        StatSlice('${m.substring(5)}/${m.substring(0, 4)}', monthCounts[m]!),
    ],
    alcohol: computeAlcohol(rows, volumeMlOf),
    previous: vorher,
  );
}

/// Länge des ausgewerteten Zeitraums in Wochen.
///
/// Bei „Alles" gibt es keine Grenze — dann zählt die Spanne vom ersten
/// Check-in bis heute. Bei einem laufenden Monat oder Jahr zählt nur die
/// **vergangene** Zeit: „Ø je Woche" über einen Monat, der erst zwei Tage
/// alt ist, wäre sonst künstlich klein.
double _weeksIn(
  List<CheckinFacts> rows,
  DateTime? from,
  DateTime? to,
  DateTime now,
) {
  final beginn = from ??
      rows.map((r) => r.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
  final ende = to == null || to.isAfter(now) ? now : to;
  final tage = ende.difference(beginn).inDays;
  return tage <= 0 ? 1 : tage / 7;
}
