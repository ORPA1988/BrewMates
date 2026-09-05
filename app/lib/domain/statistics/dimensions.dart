/// Wonach eine Auswertung gruppiert werden kann.
///
/// **Warum das eine Liste ist und kein Code:** Bis 0.10.13 hatte
/// `CheckinStats` vier benannte Felder — `byCountry`, `byStyle`,
/// `byServing`, `byBrewery`. Eine fünfte Aufteilung hieß: Feld ergänzen,
/// Konstruktor ergänzen, Auswertung ergänzen, Bildschirm ergänzen, Test
/// ergänzen. Bei vier geht das; bei zwölf ist es eine Wand.
///
/// Jetzt ist eine neue Aufteilung **ein Eintrag in [dimensions]** — der
/// Bildschirm zeigt sie, ohne dass jemand ihn anfasst.
library;

import '../../core/checkin_facts.dart';
import '../../core/serving_style.dart';

/// Eine Aufteilung: der Name für den Menschen und die Frage, welchen Wert
/// ein einzelner Check-in dazu beiträgt.
class Dimension {
  const Dimension(
    this.key,
    this.name,
    this.valueOf, {
    this.top,
    this.fixedOrder,
  });

  /// Stabiler Schlüssel — er landet in gespeicherten Ansichten und später
  /// in CSV-Spalten. **Umbenennen bricht beides**, deshalb ist er
  /// englisch und unabhängig vom angezeigten Namen.
  final String key;

  /// Überschrift und Chip-Beschriftung, deutsch (nutzersichtbar).
  final String name;

  /// Der Wert dieses Check-ins. `null` oder leer heißt „ohne Angabe" und
  /// fällt aus der Auswertung — außer die Aufteilung sagt ausdrücklich
  /// etwas anderes, wie das Gebinde.
  final String? Function(CheckinFacts) valueOf;

  /// Nur die häufigsten N zeigen. `null` = alle.
  ///
  /// Sinnvoll bei offenen Mengen (Stil, Brauerei), sinnlos bei
  /// geschlossenen (Gebinde, Wochentag) — dort ist die Liste ohnehin kurz
  /// und ein abgeschnittener Rest wäre irreführend.
  final int? top;

  /// Feste Reihenfolge statt „häufigste zuerst".
  ///
  /// Ein Wochentagsdiagramm, das mit Freitag anfängt, weil dort die
  /// meisten Einträge liegen, ist unlesbar: Man erkennt kein Muster mehr.
  /// Werte, die hier nicht vorkommen, landen hinten.
  final List<String>? fixedOrder;
}

/// Die sieben Wochentage in der Reihenfolge, in der Menschen sie denken.
const _weekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

/// Bewertungen in Halbschritten, aufsteigend — damit „was gebe ich
/// eigentlich für Noten?" als Kurve lesbar ist statt als Rangliste.
const _ratingOrder = [
  '0,5',
  '1',
  '1,5',
  '2',
  '2,5',
  '3',
  '3,5',
  '4',
  '4,5',
  '5',
];

/// Wie ein Gebinde heißt — auch der CSV-Ausgang nimmt diese Stelle,
/// damit „vom Fass" in Tabelle und Balken gleich heißt.
String servingLabel(ServingStyle? s) => switch (s) {
      ServingStyle.draft => 'vom Fass',
      ServingStyle.bottle => 'Flasche',
      ServingStyle.can => 'Dose',
      ServingStyle.growler => 'Growler',
      // Das Gebinde ist die eine Aufteilung, bei der „nichts angegeben"
      // selbst eine Antwort ist: Es sagt, wie viele Mengen geschätzt sind.
      null => 'ohne Angabe',
    };

String _ratingLabel(double r) {
  final gerundet = (r * 2).round() / 2;
  return gerundet == gerundet.roundToDouble()
      ? gerundet.toStringAsFixed(0)
      : gerundet.toStringAsFixed(1).replaceAll('.', ',');
}

/// Alle verfügbaren Aufteilungen, in der Reihenfolge der Chips.
///
/// Reihenfolge nach Nutzen, nicht alphabetisch: Stil und Land sind die
/// Fragen, die man zuerst stellt.
const List<Dimension> dimensions = [
  Dimension('style', 'Stil', _styleOf, top: 10),
  Dimension('country', 'Land', _countryOf),
  Dimension('region', 'Region', _regionOf, top: 10),
  Dimension('brewery', 'Brauerei', _breweryOf, top: 10),
  Dimension('serving', 'Gebinde', _servingOf),
  Dimension('weekday', 'Wochentag', _weekdayOf, fixedOrder: _weekdays),
  Dimension('rating', 'Bewertung', _ratingOf, fixedOrder: _ratingOrder),
  Dimension('company', 'Allein oder in Runde', _companyOf),
];

/// Die Aufteilung zu einem Schlüssel — oder die erste, wenn der
/// Schlüssel unbekannt ist (etwa aus einer alten gespeicherten Ansicht).
Dimension dimensionFor(String key) =>
    dimensions.firstWhere((d) => d.key == key, orElse: () => dimensions.first);

String? _styleOf(CheckinFacts c) => c.beerStyle;
String? _countryOf(CheckinFacts c) => c.breweryCountry;
String? _regionOf(CheckinFacts c) => c.breweryCity;
String? _breweryOf(CheckinFacts c) => c.breweryName;
String? _servingOf(CheckinFacts c) => servingLabel(c.serving);
String? _weekdayOf(CheckinFacts c) => _weekdays[c.createdAt.weekday - 1];
String? _ratingOf(CheckinFacts c) =>
    c.rating == null ? null : _ratingLabel(c.rating!);

/// Sagt etwas über die App selbst: Ist BrewMates ein Tagebuch oder ein
/// Treffpunkt? Deshalb erscheint hier **kein** „ohne Angabe" — beide
/// Fälle sind eine Antwort.
String? _companyOf(CheckinFacts c) =>
    c.sessionId == null ? 'allein' : 'in einer Runde';
