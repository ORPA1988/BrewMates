/// Was in einer Auswertung gezählt wird.
///
/// Gegenstück zu [Dimension] (`dimensions.dart`): Die Aufteilung sagt,
/// *wonach* gruppiert wird, die Kennzahl sagt, *was* dabei herauskommt.
/// Beide sind Listen statt Code, damit eine neue Zahl ein Eintrag ist und
/// kein Eingriff.
///
/// **Grundsatz:** Ausgewertet wird Vielfalt und Erinnerung, nicht
/// Leistung. Keine Kennzahl hier ist ein Ziel, eine Serie oder ein
/// Vergleich mit anderen Menschen.
library;

import '../../core/checkin_facts.dart';
import '../../core/format.dart';

/// Alles, woraus eine Kennzahl ihren Wert zieht.
///
/// Mehr als nur die Zeilen im Zeitraum: „neue Biere" braucht die Frage,
/// was **vorher** schon getrunken war, und „Ø je Woche" braucht die Länge
/// des Zeitraums. Beides gehört nicht in jede einzelne Kennzahl,
/// sondern einmal hierher.
class MeasureInput {
  const MeasureInput({
    required this.rows,
    required this.earlierBeerIds,
    required this.weeks,
    required this.totalMl,
  });

  /// Die Check-ins im gewählten Zeitraum, nach Filtern.
  final List<CheckinFacts> rows;

  /// Biere, die **vor** dem Zeitraum schon einmal dran waren.
  ///
  /// Bewusst **ungefiltert** erhoben: Ein Bier ist nicht dadurch neu, dass
  /// man gerade den Stilfilter gesetzt hat. `null` heißt „kein Zeitraum
  /// eingegrenzt" — dann ist die Frage nach neuen Bieren sinnlos, weil
  /// über die ganze Zeit jedes Bier einmal neu war.
  final Set<String>? earlierBeerIds;

  /// Länge des Zeitraums in Wochen, mindestens eine.
  final double weeks;

  /// Gesamtmenge in Millilitern, gemessen und geschätzt.
  final int totalMl;
}

/// Eine Kennzahl: Wert und Beschriftung.
class Measure {
  const Measure(this.key, this.name, this.emoji, this.valueOf, this.format);

  /// Stabiler Schlüssel für gespeicherte Ansichten und CSV-Spalten.
  final String key;

  /// Beschriftung der Kachel, deutsch (nutzersichtbar).
  final String name;

  final String emoji;

  /// Der Wert — `null` heißt **nicht anzeigen**. So blendet sich eine
  /// Kennzahl selbst aus, statt dass der Bildschirm für jede einzelne
  /// eine Sonderbedingung kennt: keine Bewertung, kein Ø; kein Ort, keine
  /// Ortskachel.
  final double? Function(MeasureInput) valueOf;

  final String Function(double) format;
}

String _asCount(double v) => v.round().toString();

String _asComma(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

String _asPerWeek(double v) =>
    '${v.toStringAsFixed(1).replaceAll('.', ',')}×';

int _distinct(List<CheckinFacts> rows, String? Function(CheckinFacts) of) =>
    {
      for (final r in rows)
        if (of(r) != null && of(r)!.isNotEmpty) of(r)!,
    }.length;

/// Alle Kennzahlen, in der Reihenfolge der Kacheln.
const List<Measure> measures = [
  Measure('checkins', 'Check-ins', '✅', _checkins, _asCount),
  Measure('beers', 'verschiedene Biere', '🍺', _beers, _asCount),
  Measure('newBeers', 'neue Biere', '✨', _newBeers, _asCount),
  Measure('breweries', 'Brauereien', '🏭', _breweries, _asCount),
  Measure('venues', 'Orte', '📍', _venues, _asCount),
  Measure('litres', 'Menge', '🍻', _litres, formatLitres),
  Measure('perWeek', 'je Woche', '📅', _perWeek, _asPerWeek),
  Measure('rating', 'Ø Bewertung', '⭐', _rating, _asComma),
  Measure('alcoholFree', 'alkoholfrei', '💧', _alcoholFree, _asCount),
];

/// Die Kennzahl zu einem Schlüssel, oder `null`.
Measure? measureFor(String key) {
  for (final m in measures) {
    if (m.key == key) return m;
  }
  return null;
}

double? _checkins(MeasureInput i) => i.rows.length.toDouble();

double? _beers(MeasureInput i) =>
    _distinct(i.rows, (r) => r.beerId).toDouble();

/// Die Kennzahl, die zur Produktvision passt: Wie viel war **neu**?
///
/// Ohne eingegrenzten Zeitraum ist sie sinnlos — über die gesamte Zeit
/// war jedes Bier einmal neu, die Zahl wäre eine Dublette von
/// „verschiedene Biere". Dann blendet sie sich aus.
double? _newBeers(MeasureInput i) {
  final earlier = i.earlierBeerIds;
  if (earlier == null) return null;
  final neu = {
    for (final r in i.rows)
      if (!earlier.contains(r.beerId)) r.beerId,
  };
  return neu.length.toDouble();
}

double? _breweries(MeasureInput i) =>
    _distinct(i.rows, (r) => r.breweryId).toDouble();

/// Orte über den **Namen**, nicht über die venueId: Freitext-Orte haben
/// keine ID, zählen aber als Ort. Schreibvarianten derselben Wirtschaft
/// werden dabei doppelt gezählt — deshalb ist der Ort eine Zahl und
/// keine Aufteilung.
double? _venues(MeasureInput i) {
  final n = _distinct(i.rows, (r) => r.venueName);
  return n == 0 ? null : n.toDouble();
}

double? _litres(MeasureInput i) => i.totalMl / 1000;

/// Macht Zeiträume vergleichbar: „42 Check-ins" sagt ohne die Dauer
/// wenig. Erst ab zwei Wochen sinnvoll — davor ist es die Rohzahl mit
/// Nachkommastelle.
double? _perWeek(MeasureInput i) =>
    i.weeks < 2 || i.rows.isEmpty ? null : i.rows.length / i.weeks;

double? _rating(MeasureInput i) {
  var summe = 0.0;
  var anzahl = 0;
  for (final r in i.rows) {
    final w = r.rating;
    if (w != null) {
      summe += w;
      anzahl++;
    }
  }
  return anzahl == 0 ? null : summe / anzahl;
}

double? _alcoholFree(MeasureInput i) {
  final n = i.rows.where((r) => r.isAlcoholFree).length;
  return n == 0 ? null : n.toDouble();
}
