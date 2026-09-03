/// Die Bilanz einer Crew — was in ihren Runden zusammengekommen ist.
///
/// **Warum das nicht `computeStats` benutzt.** Die große Auswertung
/// (Funktion 20) rechnet mit `CheckinFacts`: Füllmenge, Gebinde,
/// Brauereiland, Gasthaus. Nichts davon steht in einem Check-in, wie er
/// vom Server kommt — die Feed-Zeilen sind bewusst denormalisiert und
/// tragen Biername, Stil, Bewertung und Autor, mehr nicht.
///
/// Diese Zahlen aus fehlenden Feldern zu schätzen wäre die schlechtere
/// Antwort: „2,4 Liter" klingt nach Messung. Hier steht deshalb nur, was
/// wirklich dasteht.
library;

/// Was ein Check-in zur Crew-Bilanz beiträgt.
class CrewCheckinFacts {
  const CrewCheckinFacts({
    required this.authorId,
    required this.beerName,
    this.beerStyle,
    this.rating,
  });

  final String authorId;
  final String beerName;
  final String? beerStyle;
  final double? rating;
}

class CrewBilanz {
  const CrewBilanz({
    required this.checkins,
    required this.biere,
    required this.aktiveMitglieder,
    required this.topStile,
    this.schnitt,
    this.topBier,
  });

  final int checkins;

  /// Verschiedene Biere — die Zahl, die Vielfalt zeigt statt Menge.
  final int biere;

  /// Wie viele der Crew tatsächlich etwas beigetragen haben.
  final int aktiveMitglieder;

  /// Häufigste Stile, absteigend, höchstens drei.
  final List<({String stil, int anzahl})> topStile;

  /// Durchschnitt der **bewerteten** Check-ins; `null`, wenn keiner
  /// bewertet wurde. Unbewertete zählen nicht als Null — genau darum
  /// ging es beim Umbau der Bewertung.
  final double? schnitt;

  /// Das meistgetrunkene Bier der Crew.
  final String? topBier;

  bool get leer => checkins == 0;
}

CrewBilanz berechneCrewBilanz(List<CrewCheckinFacts> rows) {
  if (rows.isEmpty) {
    return const CrewBilanz(
      checkins: 0,
      biere: 0,
      aktiveMitglieder: 0,
      topStile: [],
    );
  }

  final proBier = <String, int>{};
  final proStil = <String, int>{};
  final autoren = <String>{};
  var bewertungen = 0;
  var summe = 0.0;

  for (final r in rows) {
    autoren.add(r.authorId);
    proBier.update(r.beerName, (n) => n + 1, ifAbsent: () => 1);
    final stil = r.beerStyle?.trim();
    if (stil != null && stil.isNotEmpty) {
      proStil.update(stil, (n) => n + 1, ifAbsent: () => 1);
    }
    final b = r.rating;
    if (b != null) {
      bewertungen++;
      summe += b;
    }
  }

  final stile = proStil.entries.map((e) => (stil: e.key, anzahl: e.value)).toList()
    ..sort((a, b) {
      final nach = b.anzahl.compareTo(a.anzahl);
      // Gleichstand alphabetisch, damit die Liste bei gleichen Zahlen
      // nicht bei jedem Aufbau springt.
      return nach != 0 ? nach : a.stil.compareTo(b.stil);
    });

  final biere = proBier.entries.toList()
    ..sort((a, b) {
      final nach = b.value.compareTo(a.value);
      return nach != 0 ? nach : a.key.compareTo(b.key);
    });

  return CrewBilanz(
    checkins: rows.length,
    biere: proBier.length,
    aktiveMitglieder: autoren.length,
    topStile: stile.take(3).toList(),
    schnitt: bewertungen == 0 ? null : summe / bewertungen,
    topBier: biere.first.key,
  );
}
