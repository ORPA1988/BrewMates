import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/domain/crew_stats.dart';

/// Die Bilanz einer Crew.
///
/// **Warum sie nicht `computeStats` benutzt:** Die große Auswertung
/// rechnet mit Füllmenge, Gebinde und Brauereiland. Nichts davon steht in
/// einer Feed-Zeile vom Server — die ist denormalisiert und trägt
/// Biername, Stil, Bewertung und Autor. Diese Zahlen aus fehlenden
/// Feldern zu schätzen wäre die schlechtere Antwort: „2,4 Liter" klingt
/// nach Messung.
void main() {
  CrewCheckinFacts c(
    String autor,
    String bier, {
    String? stil,
    double? bewertung,
  }) =>
      CrewCheckinFacts(
        authorId: autor,
        beerName: bier,
        beerStyle: stil,
        rating: bewertung,
      );

  test('ohne Check-ins ist die Bilanz leer und sagt das auch', () {
    final b = berechneCrewBilanz(const []);
    expect(b.leer, isTrue);
    expect(b.checkins, 0);
    expect(b.topBier, isNull);
    expect(b.schnitt, isNull);
  });

  test('zählt Runden, Vielfalt und wer dabei war', () {
    final b = berechneCrewBilanz([
      c('anna', 'Zwickl', stil: 'Zwickl'),
      c('anna', 'Zwickl', stil: 'Zwickl'),
      c('bert', 'Märzen', stil: 'Märzen'),
    ]);

    expect(b.checkins, 3);
    // Vielfalt statt Menge — dieselbe Haltung wie bei den Abzeichen.
    expect(b.biere, 2);
    expect(b.aktiveMitglieder, 2);
    expect(b.topBier, 'Zwickl');
  });

  test('Mitglieder, die nichts beitragen, zählen nicht als aktiv', () {
    // „dabei" heißt: hat etwas eingecheckt. Wer nur in der Crew ist,
    // erscheint in der Mitgliederliste — nicht in dieser Zahl.
    final b = berechneCrewBilanz([c('anna', 'Zwickl'), c('anna', 'Helles')]);
    expect(b.aktiveMitglieder, 1);
  });

  group('Der Schnitt', () {
    test('rechnet nur mit den bewerteten Check-ins', () {
      // Das ist der Kern: Unbewertete dürfen nicht als Null einfließen —
      // genau darum ging es beim Umbau der Bewertung.
      final b = berechneCrewBilanz([
        c('anna', 'Zwickl', bewertung: 4),
        c('bert', 'Märzen', bewertung: 5),
        c('clara', 'Helles'),
      ]);
      expect(b.schnitt, 4.5);
    });

    test('ist null, wenn niemand bewertet hat', () {
      final b = berechneCrewBilanz([c('anna', 'Zwickl')]);
      expect(b.schnitt, isNull,
          reason: 'Null Sterne wäre eine Aussage, die niemand gemacht hat.');
    });
  });

  group('Die Stile', () {
    test('kommen absteigend und höchstens zu dritt', () {
      final b = berechneCrewBilanz([
        for (var i = 0; i < 4; i++) c('a', 'Bier $i', stil: 'Zwickl'),
        for (var i = 0; i < 3; i++) c('a', 'Bier x$i', stil: 'Märzen'),
        for (var i = 0; i < 2; i++) c('a', 'Bier y$i', stil: 'Helles'),
        c('a', 'Bier z', stil: 'Pils'),
      ]);
      expect(b.topStile.map((e) => e.stil), ['Zwickl', 'Märzen', 'Helles']);
      expect(b.topStile.first.anzahl, 4);
    });

    test('bei Gleichstand alphabetisch — die Liste darf nicht springen', () {
      // Ohne feste zweite Ordnung stünde bei jedem Aufbau eine andere
      // Reihenfolge da, ohne dass sich etwas geändert hätte.
      final b = berechneCrewBilanz([
        c('a', 'x', stil: 'Weizen'),
        c('a', 'y', stil: 'Helles'),
        c('a', 'z', stil: 'Märzen'),
      ]);
      expect(b.topStile.map((e) => e.stil), ['Helles', 'Märzen', 'Weizen']);
    });

    test('Biere ohne Stil zählen mit, aber nicht als Stil', () {
      final b = berechneCrewBilanz([
        c('a', 'Namenlos'),
        c('a', 'Anderes', stil: '  '),
        c('a', 'Zwickl', stil: 'Zwickl'),
      ]);
      expect(b.checkins, 3);
      expect(b.topStile.map((e) => e.stil), ['Zwickl']);
    });
  });
}
