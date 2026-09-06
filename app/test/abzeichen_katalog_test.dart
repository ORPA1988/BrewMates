import 'package:brewmates/core/checkin_facts.dart';
import 'package:brewmates/core/serving_style.dart';
import 'package:brewmates/domain/badges.dart';
import 'package:brewmates/widgets/abzeichen_medaillon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prüft den erweiterten Abzeichen-Katalog (0.10.28) und das Medaillon.
///
/// Der Katalog ist reines Domain — er lässt sich ohne Datenbank und ohne
/// Flutter rechnen. Genau dafür wurde er in Backlog A-7 dorthin geschoben.
void main() {
  CheckinFacts ci({
    required String beerId,
    String style = 'Lager',
    String country = 'Österreich',
    String? city,
    bool alkoholfrei = false,
    double? abv,
    double? rating,
    String? note,
    String? venueName,
    int? volumeMl,
    ServingStyle? serving,
    DateTime? at,
  }) =>
      CheckinFacts(
        createdAt: at ?? DateTime(2026, 6, 15, 19),
        beerId: beerId,
        beerName: 'Testbier',
        beerStyle: style,
        isAlcoholFree: alkoholfrei,
        breweryId: 'br-1',
        breweryName: 'Brauerei',
        breweryCountry: country,
        breweryCity: city,
        abv: abv,
        rating: rating,
        note: note,
        venueName: venueName,
        volumeMl: volumeMl,
        serving: serving,
      );

  BadgeContext ctx(List<CheckinFacts> cis) =>
      BadgeContext(myCheckins: cis, mySessionCount: 0, toastsGiven: 0);

  BadgeDef abz(String slug) =>
      allBadges.firstWhere((b) => b.slug == slug, orElse: () => throw
          StateError('Abzeichen "$slug" gibt es nicht'));

  group('Katalog', () {
    test('enthält 55 Abzeichen mit eindeutigen Kürzeln', () {
      expect(allBadges, hasLength(55));
      expect(allBadges.map((b) => b.slug).toSet(), hasLength(55));
    });

    test('jedes Abzeichen hat ein erreichbares Ziel und einen Text', () {
      for (final b in allBadges) {
        expect(b.target, greaterThan(0), reason: b.slug);
        expect(b.name.trim(), isNotEmpty, reason: b.slug);
        expect(b.description.trim(), isNotEmpty, reason: b.slug);
        expect(b.emoji.trim(), isNotEmpty, reason: b.slug);
      }
    });

    // Der Grundsatz aus docs/01: belohnt werden Vielfalt, Orte und
    // Gemeinsamkeit — nie die Menge. Platin ist den Challenge-Rängen
    // vorbehalten, wo es einen echten Ersten gibt.
    test('kein Dauerabzeichen trägt Platin', () {
      final platin =
          allBadges.where((b) => b.tier == BadgeTier.platin).toList();
      expect(platin, isEmpty,
          reason: 'Platin gehört den Challenge-Rängen: '
              '${platin.map((b) => b.slug).join(", ")}');
    });

    test('jeder Rang hat eigene Metallfarben', () {
      final gesehen = <String>{};
      for (final t in BadgeTier.values) {
        expect(t.farbverlauf, hasLength(3), reason: t.name);
        expect(gesehen.add(t.farbverlauf.join('-')), isTrue,
            reason: '${t.name} hat denselben Verlauf wie ein anderer Rang');
      }
    });

    test('Bronze ist das Kupfer der Palette', () {
      // BrewTheme.copper = 0xFFB4632C. Bronze ist dessen mittlere Stufe —
      // damit ist der Metallrand kein Fremdkörper in „Abend in der Bar".
      expect(BadgeTier.bronze.farbverlauf[1], 0xFFB4632C);
    });
  });

  group('Neue Rechenvorschriften zählen Vielfalt, nicht Menge', () {
    test('Stil-Abzeichen zählen verschiedene Biere, nicht Check-ins', () {
      // Fünfmal dasselbe Pils ist ein Pils.
      final einmal = List.generate(5, (_) => ci(beerId: 'p1', style: 'Pils'));
      expect(abz('pils-purist').progressOf(ctx(einmal)), 1);

      final fuenf = List.generate(
          5, (i) => ci(beerId: 'p$i', style: i.isEven ? 'Pils' : 'Pils Spezial'));
      expect(abz('pils-purist').progressOf(ctx(fuenf)), 5);
    });

    test('Weißbier erkennt Weizen, Weissbier und Weißbier', () {
      final cis = [
        ci(beerId: 'a', style: 'Weißbier'),
        ci(beerId: 'b', style: 'Weissbier hell'),
        ci(beerId: 'c', style: 'Hefeweizen'),
        ci(beerId: 'd', style: 'Pils'),
      ];
      expect(abz('weissbier-freund').progressOf(ctx(cis)), 3);
    });

    test('Herkunft vergleicht ohne Rücksicht auf Groß- und Kleinschreibung',
        () {
      final cis = [
        ci(beerId: 'a', country: 'Österreich'),
        ci(beerId: 'b', country: 'österreich '),
        ci(beerId: 'c', country: 'Deutschland'),
      ];
      expect(abz('heimatliebe').progressOf(ctx(cis)), 2);
      expect(abz('nachbarschaft').progressOf(ctx(cis)), 1);
      expect(abz('eidgenosse').progressOf(ctx(cis)), 0);
    });

    test('Stammlokal nimmt das häufigste Gasthaus, nicht die Summe', () {
      final cis = [
        ...List.generate(4, (i) => ci(beerId: 'a$i', venueName: 'Bräu')),
        ...List.generate(2, (i) => ci(beerId: 'b$i', venueName: 'Keller')),
        ci(beerId: 'c', venueName: '   '),
        ci(beerId: 'd'),
      ];
      expect(abz('stammlokal').progressOf(ctx(cis)), 4);
    });

    test('Jahreszeiten zählt vier Quartale, egal wie viele Check-ins', () {
      final cis = [
        ci(beerId: 'a', at: DateTime(2026, 1, 5)),
        ci(beerId: 'b', at: DateTime(2026, 2, 5)),
        ci(beerId: 'c', at: DateTime(2026, 4, 5)),
        ci(beerId: 'd', at: DateTime(2026, 8, 5)),
        ci(beerId: 'e', at: DateTime(2026, 11, 5)),
      ];
      expect(abz('jahreszeiten').progressOf(ctx(cis)), 4);
    });

    test('Alkoholgehalt ohne Wert zählt nirgends mit', () {
      final cis = [
        ci(beerId: 'a', abv: null),
        ci(beerId: 'b', abv: 0),
        ci(beerId: 'c', abv: 3.2),
        ci(beerId: 'd', abv: 8.5),
      ];
      expect(abz('leichtfuss').progressOf(ctx(cis)), 1);
      expect(abz('schwergewicht').progressOf(ctx(cis)), 1);
    });

    test('Gebinde und Sorgfalt lesen die richtigen Felder', () {
      final cis = [
        ci(beerId: 'a', serving: ServingStyle.draft, volumeMl: 500),
        ci(beerId: 'b', serving: ServingStyle.bottle, volumeMl: 330),
        ci(beerId: 'c', volumeMl: 0),
        ci(beerId: 'd', rating: 1.5, note: '  '),
        ci(beerId: 'e', rating: 5.0, note: 'malzig'),
      ];
      expect(abz('vom-fass').progressOf(ctx(cis)), 1);
      expect(abz('flaschenpost').progressOf(ctx(cis)), 1);
      expect(abz('kleines-glas').progressOf(ctx(cis)), 1);
      expect(abz('bewerter').progressOf(ctx(cis)), 2);
      expect(abz('ehrlich-geblieben').progressOf(ctx(cis)), 1);
      expect(abz('begeistert').progressOf(ctx(cis)), 1);
      expect(abz('kritiker-2').progressOf(ctx(cis)), 1);
    });
  });

  group('Medaillon', () {
    testWidgets('zeichnet verdient und gesperrt ohne Absturz', (tester) async {
      for (final verdient in [true, false]) {
        for (final t in BadgeTier.values) {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Center(
                child: AbzeichenMedaillon(
                  emoji: '🍺',
                  tier: t,
                  anteil: 0.4,
                  verdient: verdient,
                ),
              ),
            ),
          ));
          expect(find.byType(AbzeichenMedaillon), findsOneWidget);
        }
      }
    });

    testWidgets('legt keine Deckkraft über die Kachel', (tester) async {
      // Der Fehler, den es zu verhindern gilt: Bis 0.10.27 lag
      // Opacity(0.35) über Symbol UND Schrift, womit der Textkontrast
      // unter 4,5:1 fiel.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AbzeichenMedaillon(
              emoji: '🍺',
              tier: BadgeTier.bronze,
              anteil: 0.2,
              verdient: false,
            ),
          ),
        ),
      ));
      expect(find.byType(Opacity), findsNothing);
    });
  });
}
