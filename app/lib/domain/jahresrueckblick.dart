/// Dein Bierjahr in Zahlen — die Rechnung hinter dem Rückblick (#167).
///
/// **Was hier bewusst nicht steht:** kein Ranking, kein Vergleich, kein
/// „mehr als letztes Jahr". Ein Rückblick, der einem sagt, man habe sich
/// gesteigert, ist eine Aufforderung. Gezählt wird Vielfalt und
/// Erinnerung — dieselbe Grenze wie in `statistics/measures.dart`.
///
/// Reine Logik, keine Datenbank, kein Widget: Was hier herauskommt, ist
/// eine Liste von Zeilen, und eine Liste kann ein Test prüfen.
library;

import '../core/checkin_facts.dart';
import 'wochen_verlauf.dart';

/// Eine Zeile des Rückblicks: Zahl, Beschriftung, Emoji.
class Rueckblickzeile {
  const Rueckblickzeile(this.emoji, this.wert, this.beschriftung);

  final String emoji;

  /// Schon fertig formatiert — „37", „Stiegl-Goldbräu", „im August".
  final String wert;

  final String beschriftung;
}

/// Alles, was im Rückblick steht.
class Jahresrueckblick {
  const Jahresrueckblick({
    required this.jahr,
    required this.checkins,
    required this.zeilen,
    required this.wochen,
  });

  final int jahr;

  /// Check-ins im Jahr. Steht separat, weil die Oberfläche daran
  /// entscheidet, ob es überhaupt etwas zu zeigen gibt.
  final int checkins;

  final List<Rueckblickzeile> zeilen;

  /// Die 52 Wochen des Jahres für die Heatmap
  /// (`widgets/wochen_heatmap.dart`).
  final List<Wochenwert> wochen;

  bool get istLeer => checkins == 0;
}

const _monate = [
  'Jänner', 'Februar', 'März', 'April', 'Mai', 'Juni', //
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Häufigster Wert einer Gruppierung, bei Gleichstand alphabetisch.
///
/// Der Gleichstand ist nicht theoretisch: Wer zweimal Gösser und zweimal
/// Stiegl getrunken hat, soll nicht je nach Sortierung der Datenbank ein
/// anderes „Lieblingsbier" bekommen. Ein Rückblick, der sich beim
/// zweiten Öffnen ändert, ist kaputt.
String? _haeufigster(Iterable<String> werte) {
  final zaehler = <String, int>{};
  for (final w in werte) {
    if (w.trim().isEmpty) continue;
    zaehler[w] = (zaehler[w] ?? 0) + 1;
  }
  if (zaehler.isEmpty) return null;
  final sortiert = zaehler.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return sortiert.first.key;
}

/// Rechnet den Rückblick für [jahr] aus **allen** Check-ins.
///
/// Absichtlich alle und nicht nur die des Jahres: „neu entdeckt" braucht
/// die Frage, was vorher schon dran war. Wer das vorfiltert, bekommt in
/// jedem Jahr lauter Neuentdeckungen.
Jahresrueckblick jahresrueckblick(
  Iterable<CheckinFacts> alle,
  int jahr,
) {
  final imJahr = [
    for (final c in alle)
      if (c.createdAt.year == jahr) c,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  // Der Silvesterabend gehört noch ins alte Jahr: Ende ist der 1. Jänner
  // des Folgejahres, und `wochenVerlauf` rechnet von dort zurück. 53
  // Wochen, weil ein Jahr nie in 52 volle Wochen passt.
  final wochen = wochenVerlauf(
    imJahr.map((c) => c.createdAt),
    DateTime(jahr, 12, 31),
    wochen: 53,
  );

  if (imJahr.isEmpty) {
    return Jahresrueckblick(
        jahr: jahr, checkins: 0, zeilen: const [], wochen: wochen);
  }

  final vorher = {
    for (final c in alle)
      if (c.createdAt.year < jahr) c.beerId,
  };
  final neueBiere = {
    for (final c in imJahr)
      if (!vorher.contains(c.beerId)) c.beerId,
  };

  final proMonat = <int, int>{};
  for (final c in imJahr) {
    proMonat[c.createdAt.month] = (proMonat[c.createdAt.month] ?? 0) + 1;
  }
  final besterMonat = proMonat.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });

  final laengsteSerie = _laengsteSerie(wochen);
  final lieblingsbier = _haeufigster(imJahr.map((c) => c.beerName));
  final lieblingsstil = _haeufigster(imJahr.map((c) => c.beerStyle));
  final runden = {
    for (final c in imJahr)
      if (c.sessionId != null) c.sessionId!,
  };
  final orte = {
    for (final c in imJahr)
      if (c.venueId != null || (c.venueName?.trim().isNotEmpty ?? false))
        c.venueId ?? c.venueName!.trim().toLowerCase(),
  };

  return Jahresrueckblick(
    jahr: jahr,
    checkins: imJahr.length,
    wochen: wochen,
    zeilen: [
      Rueckblickzeile('🍺', '${imJahr.length}',
          imJahr.length == 1 ? 'Check-in' : 'Check-ins'),
      Rueckblickzeile(
          '🏷️',
          '${imJahr.map((c) => c.beerId).toSet().length}',
          'verschiedene Biere'),
      Rueckblickzeile(
          '🏭',
          '${imJahr.map((c) => c.breweryId).toSet().length}',
          'Brauereien'),
      Rueckblickzeile(
          '🎨',
          '${imJahr.map((c) => c.beerStyle.toLowerCase()).toSet().length}',
          'Stile'),
      if (neueBiere.isNotEmpty)
        Rueckblickzeile('✨', '${neueBiere.length}', 'zum ersten Mal'),
      if (lieblingsbier != null)
        Rueckblickzeile('❤️', lieblingsbier, 'am häufigsten im Glas'),
      if (lieblingsstil != null)
        Rueckblickzeile('🍯', lieblingsstil, 'liebster Stil'),
      if (orte.isNotEmpty)
        Rueckblickzeile('📍', '${orte.length}',
            orte.length == 1 ? 'Ort' : 'verschiedene Orte'),
      if (runden.isNotEmpty)
        Rueckblickzeile('🍻', '${runden.length}',
            runden.length == 1 ? 'Runde' : 'Runden mit anderen'),
      Rueckblickzeile('📅', 'im ${_monate[besterMonat.first.key - 1]}',
          'war am meisten los'),
      if (laengsteSerie > 1)
        Rueckblickzeile('🔥', '$laengsteSerie', 'Wochen am Stück'),
    ],
  );
}

/// Längste ununterbrochene Folge von Wochen mit mindestens einem Check-in.
int _laengsteSerie(List<Wochenwert> wochen) {
  var beste = 0;
  var laufend = 0;
  for (final w in wochen) {
    laufend = w.anzahl > 0 ? laufend + 1 : 0;
    if (laufend > beste) beste = laufend;
  }
  return beste;
}

/// Die Jahre, für die es überhaupt einen Rückblick gibt — neuestes zuerst.
List<int> rueckblickJahre(Iterable<CheckinFacts> alle) {
  final jahre = {for (final c in alle) c.createdAt.year}.toList()
    ..sort((a, b) => b.compareTo(a));
  return jahre;
}
