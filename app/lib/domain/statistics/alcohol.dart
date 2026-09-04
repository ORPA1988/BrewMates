/// Reinalkohol im ausgewerteten Zeitraum.
///
/// **Warum diese Zahl eine Sonderbehandlung bekommt.** Sie ist die
/// aussagekräftigste Angabe über den eigenen Konsum — und die einzige in
/// diesem Bereich, die einen Menschen unangenehm treffen kann. Die
/// Produktvision sagt: Vielfalt und Erinnerung, nicht Leistung. Eine
/// Alkoholzahl verstößt nicht dagegen (sie ist kein Wettbewerb), aber
/// sie ist auch keine Erinnerung. Sie ist ein Spiegel.
///
/// Deshalb steht sie **nicht** unter den Kennzahl-Kacheln, sondern in
/// einer eigenen Karte weiter unten — und deshalb ist sie hier eine
/// eigene Datei statt eines neunten Eintrags in `measures.dart`.
///
/// Entschieden vom Menschen am 2026-09-04 (Regel K in `CLAUDE.md`,
/// Vorschlag in docs/features/20, Punkt 6): anzeigen, sachlich, mit
/// ausgewiesenem Schätzanteil — nie als Serie, Ziel, Rekord, Vergleich
/// mit anderen oder Warnung.
library;

import '../../core/checkin_facts.dart';

/// Dichte von Ethanol in g/ml bei Raumtemperatur.
const double _ethanolDichte = 0.789;

/// Was sich über den Alkohol im Zeitraum sagen lässt — samt dem, was sich
/// **nicht** sagen lässt.
class AlcoholSummary {
  const AlcoholSummary({
    required this.pureMl,
    required this.countedCheckins,
    required this.withoutAbv,
    required this.estimatedVolume,
  });

  static const empty = AlcoholSummary(
    pureMl: 0,
    countedCheckins: 0,
    withoutAbv: 0,
    estimatedVolume: 0,
  );

  /// Milliliter reiner Alkohol.
  final double pureMl;

  /// Wie viele Check-ins in die Zahl eingehen konnten.
  final int countedCheckins;

  /// Wie viele nicht — weil das Bier keinen Alkoholgehalt hinterlegt hat.
  /// Bei nutzererstellten Bieren ist das häufig.
  final int withoutAbv;

  /// Wie viele der gezählten eine **geschätzte** Füllmenge hatten. Wo die
  /// Menge geschätzt ist, ist die Alkoholzahl es auch — das gehört
  /// dazugesagt, sonst behauptet sie eine Genauigkeit, die sie nicht hat.
  final int estimatedVolume;

  /// Gramm reiner Alkohol.
  double get pureGrams => pureMl * _ethanolDichte;

  /// Lässt sich überhaupt etwas sagen?
  bool get hasValue => countedCheckins > 0;

  /// Anteil der Check-ins, die mangels Alkoholgehalt fehlen.
  ///
  /// Ab etwa einem Drittel ist die Zahl mehr Lücke als Aussage — die
  /// Anzeige sagt das dann deutlicher.
  bool get isPatchy =>
      withoutAbv > 0 && withoutAbv >= (countedCheckins + withoutAbv) / 3;
}

/// Rechnet den Reinalkohol über [rows].
///
/// [volumeOf] liefert die Menge eines Check-ins (gemessen oder
/// geschätzt) — dieselbe Funktion, die auch die Literzahl bildet, damit
/// beide Zahlen nicht auseinanderlaufen können.
AlcoholSummary computeAlcohol(
  List<CheckinFacts> rows,
  int Function(CheckinFacts) volumeOf,
) {
  var ml = 0.0;
  var gezaehlt = 0;
  var ohneAbv = 0;
  var geschaetzt = 0;

  for (final r in rows) {
    final abv = r.abv;
    // Alkoholfreies Bier hat oft gar keinen oder einen sehr kleinen Wert
    // hinterlegt; beides ist richtig und trägt schlicht wenig bei. Nur
    // ein fehlender Wert ist eine Lücke.
    if (abv == null) {
      ohneAbv++;
      continue;
    }
    ml += volumeOf(r) * abv / 100;
    gezaehlt++;
    if (r.volumeMl == null) geschaetzt++;
  }

  return AlcoholSummary(
    pureMl: ml,
    countedCheckins: gezaehlt,
    withoutAbv: ohneAbv,
    estimatedVolume: geschaetzt,
  );
}
