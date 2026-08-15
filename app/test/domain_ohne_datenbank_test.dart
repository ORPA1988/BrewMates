import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/checkin_facts.dart';
import 'package:brewmates/domain/badges.dart';
import 'package:brewmates/domain/challenges.dart';

/// Abzeichen- und Challenge-Logik **ohne Datenbank**.
///
/// Vor dem Umbau (Backlog A-7) ging das nicht: Beide Dateien importierten
/// Drift, und `ChallengeEngine`/`BadgeEngine` brauchten eine echte
/// `AppDatabase`. Geprüft wurde die Regelauswertung deshalb nur über den
/// Umweg einer In-Memory-Datenbank — also nie die Regel allein.
///
/// Dass diese Datei kein `data/` importiert, ist der Beleg, dass der
/// Umbau echt war und nicht nur verschoben hat.
void main() {
  final now = DateTime(2026, 8, 15, 20);

  CheckinFacts fact({
    DateTime? at,
    String beerId = 'b1',
    String style = 'Märzen',
    String breweryId = 'br1',
    String country = 'AT',
    bool alkoholfrei = false,
    String? venueId,
    String? venueName,
    String? note,
  }) =>
      CheckinFacts(
        createdAt: at ?? now,
        beerId: beerId,
        beerStyle: style,
        isAlcoholFree: alkoholfrei,
        breweryId: breweryId,
        breweryName: 'Brauerei',
        breweryCountry: country,
        venueId: venueId,
        venueName: venueName,
        note: note,
      );

  ChallengeDef? regel(String ruleJson) => ChallengeDef.fromRule(
        id: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        title: 'Test',
        description: 'Test',
        emoji: '🍺',
        startsAt: DateTime(2026, 8, 1),
        endsAt: DateTime(2026, 9, 1),
        ruleJson: ruleJson,
      );

  group('Challenge-Regeln', () {
    test('distinct_styles zählt Stile, nicht Check-ins', () {
      final def = regel('{"type":"distinct_styles","threshold":2}')!;
      expect(
        def.progressFor([
          fact(style: 'Märzen'),
          fact(style: 'Märzen'),
          fact(style: 'Pils'),
        ]),
        2,
      );
    });

    test('style_specific ist case-insensitive und zählt Biere', () {
      final def =
          regel('{"type":"style_specific","style":"pils","threshold":2}')!;
      expect(
        def.progressFor([
          fact(beerId: 'a', style: 'PILS'),
          fact(beerId: 'a', style: 'Pils'), // dasselbe Bier
          fact(beerId: 'b', style: 'Kellerpils'),
        ]),
        2,
      );
    });

    test('venue_checkins zählt Orte, auch ohne venueId als Freitext', () {
      final def = regel('{"type":"venue_checkins","threshold":2}')!;
      expect(
        def.progressFor([
          fact(venueId: 'v1', venueName: 'Augustiner'),
          fact(venueName: 'Stiegl-Keller'), // nur Freitext
          fact(venueName: '   '), // leer zählt nicht
          fact(), // gar kein Ort
        ]),
        2,
      );
    });

    test('Nur Check-ins im Zeitfenster zählen', () {
      final def = regel('{"type":"checkins_count","threshold":5}')!;
      expect(
        def.progressFor([
          fact(at: DateTime(2026, 7, 31, 23)), // davor
          fact(at: DateTime(2026, 8, 15)), // drin
          fact(at: DateTime(2026, 9, 1)), // Ende ist exklusiv
        ]),
        1,
      );
    });

    test('Unbekannter Regeltyp ergibt null statt eines Absturzes', () {
      // Eine Challenge, die neuer ist als die App, darf nichts kaputt
      // machen — sie wird übersprungen.
      expect(regel('{"type":"trinkmenge","threshold":10}'), isNull);
      expect(regel('kein json'), isNull);
      expect(regel('{"type":"checkins_count"}'), isNull, reason: 'ohne Ziel');
      expect(regel('{"type":"checkins_count","threshold":0}'), isNull,
          reason: 'Ziel 0 wäre sofort erfüllt');
    });
  });

  group('Abzeichen', () {
    BadgeContext ctx(List<CheckinFacts> checkins) =>
        BadgeContext(myCheckins: checkins, mySessionCount: 0, toastsGiven: 0);

    test('Der Katalog belohnt Vielfalt, nicht Menge', () {
      // Grundsatz aus docs/01-produktvision.md. Kein Abzeichen darf sein
      // Ziel allein durch viele Check-ins DESSELBEN Biers erreichen —
      // ausser den bewussten Einstiegs-/Treue-Abzeichen.
      final einBier = [for (var i = 0; i < 50; i++) fact()];
      final erreichbar = allBadges
          .where((b) => b.progressOf(ctx(einBier)) >= b.target)
          .map((b) => b.slug)
          .toSet();

      expect(erreichbar.contains('erster-schluck'), isTrue,
          reason: 'Das erste Bier soll zählen');
      expect(erreichbar.contains('weltenbummler'), isFalse,
          reason: 'Länder-Abzeichen darf nicht mit einem Bier fallen');
    });

    test('Fortschritt zählt verschiedene Länder, nicht Check-ins', () {
      final stileWeit = [
        fact(country: 'AT'),
        fact(country: 'AT'),
        fact(country: 'DE'),
      ];
      final laenderBadge =
          allBadges.firstWhere((b) => b.slug == 'weltenbummler');
      expect(laenderBadge.progressOf(ctx(stileWeit)), 2);
    });
  });
}
