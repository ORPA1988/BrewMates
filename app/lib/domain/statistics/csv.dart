/// Auswertung und Rohdaten als CSV — der Ausgang neben der Anzeige.
///
/// Reine Funktionen über `CheckinFacts` und `StatSlice`: kein Widget,
/// keine Datenbank, keine Datei. **Wohin** das Ergebnis geht, entscheidet
/// die Oberfläche (`core/export/`); hier entsteht nur Text.
///
/// Die Kette `Liste → Auswahl → Aufteilung → Zahlen` macht das billig:
/// CSV ist ein anderer Ausgang an derselben Stelle, kein zweiter Weg
/// durch die Daten (docs/features/20, Punkt 7).
library;

import '../../core/checkin_facts.dart';
import '../statistics.dart' show StatSlice;
import 'dimensions.dart';

/// Trennzeichen und Kopfzeile für Excel in deutscher Ländereinstellung.
///
/// **`sep=;` muss in der ersten Zeile stehen**, sonst zerlegt Excel eine
/// Semikolon-Datei nicht — es erwartet dort das Komma. Das ist kein
/// Standard, aber es ist die Wirklichkeit auf den Rechnern, auf denen
/// diese Datei geöffnet wird.
const _trenner = ';';
const _sepZeile = 'sep=$_trenner';

/// UTF-8-BOM. Ohne sie macht Excel aus „Gösser" ein „GÃ¶sser".
const csvBom = '\uFEFF';

/// Eine Zeile je Check-in — der Datenauszug.
///
/// Zahlen mit **Punkt** als Dezimaltrenner und Datum als ISO
/// (`2026-09-05`): maschinenlesbar schlägt hübsch. Wer die Datei in
/// Excel öffnet, sieht ohnehin die Anzeigeform seiner Ländereinstellung;
/// wer sie weiterverarbeitet, braucht die eindeutige.
String rohdatenCsv(List<CheckinFacts> rows) {
  final zeilen = <String>[
    _sepZeile,
    [
      'datum',
      'uhrzeit',
      'bier',
      'stil',
      'alkoholfrei',
      'alkohol_prozent',
      'brauerei',
      'land',
      'stadt',
      'ort',
      'menge_ml',
      'gebinde',
      'bewertung',
      'in_runde',
      'notiz',
    ].join(_trenner),
  ];

  // Älteste zuerst: Eine Tabelle liest man von oben nach unten durch die
  // Zeit, anders als einen Feed.
  final sortiert = [...rows]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  for (final r in sortiert) {
    zeilen.add([
      _datum(r.createdAt),
      _uhrzeit(r.createdAt),
      _feld(r.beerName),
      _feld(r.beerStyle),
      r.isAlcoholFree ? 'ja' : 'nein',
      _zahl(r.abv),
      _feld(r.breweryName),
      _feld(r.breweryCountry),
      _feld(r.breweryCity ?? ''),
      _feld(r.venueName ?? ''),
      r.volumeMl?.toString() ?? '',
      _feld(r.serving == null ? '' : servingLabel(r.serving)),
      _zahl(r.rating),
      r.sessionId == null ? 'nein' : 'ja',
      _feld(r.note ?? ''),
    ].join(_trenner));
  }
  return zeilen.join('\r\n');
}

/// Eine Zeile je Balken der gewählten Aufteilung — die Auswertung.
///
/// Für den, der schnell eine Tabelle in eine Nachricht kopieren will.
String auswertungCsv(String dimensionKey, List<StatSlice> slices) {
  final name = dimensionFor(dimensionKey).name;
  final gesamt = slices.fold<int>(0, (summe, e) => summe + e.count);
  return [
    _sepZeile,
    [_feld(name), 'anzahl', 'anteil_prozent'].join(_trenner),
    for (final s in slices)
      [
        _feld(s.label),
        s.count.toString(),
        // Auf eine Nachkommastelle: Mehr behauptete eine Genauigkeit,
        // die bei zwölf Check-ins niemand hat.
        gesamt == 0 ? '0' : (s.count * 100 / gesamt).toStringAsFixed(1),
      ].join(_trenner),
  ].join('\r\n');
}

String _datum(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _uhrzeit(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _zahl(double? v) => v == null ? '' : v.toString();

/// Ein Feld so einpacken, dass es die Tabelle nicht zerreißt.
///
/// Notizen enthalten Semikolons, Anführungszeichen und Zeilenumbrüche —
/// alle drei zerlegen eine CSV-Datei, wenn man sie roh hineinschreibt.
/// Die Regel dafür ist alt und einfach (RFC 4180): in Anführungszeichen
/// setzen, und innere Anführungszeichen verdoppeln.
String _feld(String wert) {
  if (!wert.contains(_trenner) &&
      !wert.contains('"') &&
      !wert.contains('\n') &&
      !wert.contains('\r')) {
    return wert;
  }
  return '"${wert.replaceAll('"', '""')}"';
}
