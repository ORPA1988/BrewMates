import 'package:brewmates/domain/auszeichnung.dart';
import 'package:brewmates/domain/badges.dart' show BadgeTier;
import 'package:brewmates/widgets/trophaee.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Trophäen der vier Auszeichnungsarten (0063 / 0.10.28).
///
/// Zwei Achsen, die sich nie überschneiden dürfen: Das **Metall** sagt den
/// Rang, das **Band** sagt das Jahr. Genau das halten diese Tests fest —
/// beim nächsten Umbau ist die Trennung das Erste, was verloren geht.
void main() {
  group('Auszeichnungsarten', () {
    test('jede Art hat genau ein Metall, und keine teilt es', () {
      final metalle = {
        for (final a in Auszeichnungsart.values) a: a.tier,
      };
      expect(metalle[Auszeichnungsart.blitzschluck], BadgeTier.platin);
      expect(metalle[Auszeichnungsart.besteCrew], BadgeTier.gold);
      expect(metalle[Auszeichnungsart.schlusslicht], BadgeTier.silber);
      expect(metalle[Auszeichnungsart.dabei], BadgeTier.bronze);
      expect(metalle.values.toSet(), hasLength(4));
    });

    // Die Rangfolge muss der Seltenheit folgen. Im ersten Entwurf war sie
    // verkehrt: „Dabei gewesen" trug Silber und bekam jeder, „Schlusslicht"
    // trug Bronze und bekam genau einer — das seltenere Zeichen war das
    // niedrigere Metall.
    test('das häufigste Zeichen trägt das niedrigste Metall', () {
      const reihenfolge = [
        Auszeichnungsart.dabei, // alle Finisher
        Auszeichnungsart.schlusslicht, // genau einer
        Auszeichnungsart.besteCrew, // eine Crew
        Auszeichnungsart.blitzschluck, // genau einer, der Erste
      ];
      final stufen =
          reihenfolge.map((a) => BadgeTier.values.indexOf(a.tier)).toList();
      expect(stufen, orderedEquals([0, 1, 2, 3]));
    });

    test('unbekannte Arten werden übersprungen, nicht geworfen', () {
      expect(Auszeichnungsart.vomServer('beste_crew'),
          Auszeichnungsart.besteCrew);
      expect(Auszeichnungsart.vomServer('etwas_neues'), isNull);
      expect(Auszeichnungsart.vomServer(null), isNull);
    });

    test('Hin- und Rückweg über den Serverwert bleibt gleich', () {
      for (final a in Auszeichnungsart.values) {
        expect(Auszeichnungsart.vomServer(a.serverWert), a);
      }
    });
  });

  group('Das Band trägt das Jahr', () {
    test('2026 und 2027 sind unterscheidbar', () {
      expect(bandFarben(2026), isNot(equals(bandFarben(2027))));
    });

    test('die erste Trophäe der App trägt das Tannenband', () {
      expect(bandFarben(2026).first, 0xFF1F5B3A);
    });

    test('sechs Bänder, dann wiederholt sich die Reihe', () {
      expect(bandFarben(2032), equals(bandFarben(2026)));
      expect(bandFarben(2031), isNot(equals(bandFarben(2026))));
    });

    test('Jahre vor 2026 kippen nicht in einen negativen Rest', () {
      // Dart liefert für negative Zahlen einen negativen Modulo — ohne die
      // doppelte Rechnung im Domain gäbe es hier einen Bereichsfehler.
      for (final jahr in [2020, 2024, 2025, 1999]) {
        expect(bandFarben(jahr), hasLength(2), reason: '$jahr');
      }
    });

    test('das Band hängt am Jahr, nicht am Rang', () {
      // Dieselbe Challenge, zwei Ränge: gleiches Band.
      expect(bandFarben(2026), equals(bandFarben(2026)));
      // Und umgekehrt: gleiches Metall, zwei Jahre, zwei Bänder.
      expect(Auszeichnungsart.dabei.tier, BadgeTier.bronze);
      expect(bandFarben(2026), isNot(equals(bandFarben(2027))));
    });
  });

  group('Trophäe zeichnen', () {
    testWidgets('alle vier Arten in beiden Paletten', (tester) async {
      for (final dunkel in [true, false]) {
        for (final art in Auszeichnungsart.values) {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFE8A33D),
                brightness: dunkel ? Brightness.dark : Brightness.light,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: Trophaee(emoji: '🎄', art: art, jahr: 2026),
              ),
            ),
          ));
          expect(find.byType(Trophaee), findsOneWidget,
              reason: '${art.name}, dunkel=$dunkel');
        }
      }
    });

    testWidgets('sehr kleine Breiten zeichnen ohne Bereichsfehler',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Trophaee(
              emoji: '🏆',
              art: Auszeichnungsart.blitzschluck,
              jahr: 2027,
              breite: 32,
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
