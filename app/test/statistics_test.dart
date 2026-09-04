import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/format.dart';
import 'package:brewmates/core/checkin_facts.dart';
import 'package:brewmates/core/serving_style.dart';
import 'package:brewmates/domain/statistics.dart';

/// Reine Auswertung — ohne Flutter, ohne Datenbank.
///
/// Dass dieser Test `data/` nicht mehr importiert, ist kein Zufall,
/// sondern der Beleg: Die Auswertung hängt an keiner Drift-Zeile mehr,
/// sondern an [CheckinFacts]. Kommt hier je wieder ein Import aus `data/`
/// dazu, ist die Schichtregel erneut gebrochen.
void main() {
  final now = DateTime(2026, 8, 15, 20);
  const alles = StatsPeriod.preset(StatsRange.all);
  const diesesJahr = StatsPeriod.preset(StatsRange.year);
  const dieserMonat = StatsPeriod.preset(StatsRange.month);

  CheckinFacts detail({
    required String id,
    required DateTime at,
    String style = 'Märzen',
    String country = 'AT',
    int? volumeMl,
    ServingStyle? serving,
    double? rating,
    bool alcoholFree = false,
    String? venueName,
    String breweryName = 'Stiegl',
    String? city,
    String? sessionId,
    double? abv,
  }) =>
      CheckinFacts(
        createdAt: at,
        beerId: 'beer-$id',
        beerStyle: style,
        isAlcoholFree: alcoholFree,
        breweryId: 'b1',
        breweryName: breweryName,
        breweryCountry: country,
        breweryCity: city,
        sessionId: sessionId,
        abv: abv,
        venueName: venueName,
        volumeMl: volumeMl,
        serving: serving,
        rating: rating,
      );

  test('Leere Eingabe ergibt eine leere Auswertung', () {
    final stats = computeStats(const [], now: now, period: alles);
    expect(stats.isEmpty, isTrue);
    expect(stats.totalMl, 0);
    expect(stats.value('rating'), isNull);
  });

  test('Gemessene Mengen werden summiert, nichts geschätzt', () {
    final stats = computeStats([
      detail(id: '1', at: now, volumeMl: 500),
      detail(id: '2', at: now, volumeMl: 330),
    ], now: now, period: alles);

    expect(stats.totalMl, 830);
    expect(stats.estimatedCount, 0);
    expect(stats.volumeIsRough, isFalse);
  });

  test('Fehlende Menge wird nach Gebinde geschätzt und ausgewiesen', () {
    // Alte Check-ins haben keine Menge. Sie wegzulassen würde die Zahl
    // ohne Vorwarnung zu klein machen; sie als gemessen auszugeben wäre
    // eine Lüge. Also: schätzen und dazusagen.
    final stats = computeStats([
      detail(id: '1', at: now, serving: ServingStyle.growler),
      detail(id: '2', at: now, serving: ServingStyle.bottle),
      detail(id: '3', at: now), // gar keine Angabe
    ], now: now, period: alles);

    expect(stats.totalMl, 1000 + 500 + defaultVolumeMl);
    expect(stats.estimatedCount, 3);
    expect(stats.volumeIsRough, isTrue);
  });

  test('Gemessenes schlägt die Schätzung', () {
    final stats = computeStats([
      detail(id: '1', at: now, serving: ServingStyle.growler, volumeMl: 250),
    ], now: now, period: alles);

    expect(stats.totalMl, 250);
    expect(stats.estimatedCount, 0);
  });

  test('Zeitraum schneidet Älteres ab', () {
    final rows = [
      detail(id: 'alt', at: DateTime(2025, 5, 1)),
      detail(id: 'jahr', at: DateTime(2026, 2, 1)),
      detail(id: 'monat', at: DateTime(2026, 8, 3)),
    ];

    expect(computeStats(rows, now: now, period: alles).checkins, 3);
    expect(computeStats(rows, now: now, period: diesesJahr).checkins, 2);
    expect(computeStats(rows, now: now, period: dieserMonat).checkins, 1);
  });

  test('Filter für Land und Stil greifen einzeln und gemeinsam', () {
    final rows = [
      detail(id: '1', at: now, country: 'AT', style: 'Märzen'),
      detail(id: '2', at: now, country: 'DE', style: 'Märzen'),
      detail(id: '3', at: now, country: 'AT', style: 'Pils'),
    ];

    expect(computeStats(rows, now: now, country: 'AT').checkins, 2);
    expect(computeStats(rows, now: now, style: 'Märzen').checkins, 2);
    expect(
        computeStats(rows, now: now, country: 'AT', style: 'Pils').checkins, 1);
    expect(computeStats(rows, now: now, country: 'CH').isEmpty, isTrue);
  });

  test('Aufteilungen zählen richtig, häufigste zuerst', () {
    final stats = computeStats([
      detail(id: '1', at: now, style: 'Märzen'),
      detail(id: '2', at: now, style: 'Märzen'),
      detail(id: '3', at: now, style: 'Pils'),
    ], now: now, period: alles);

    expect(stats.slices('style').first.label, 'Märzen');
    expect(stats.slices('style').first.count, 2);
    expect(stats.slices('style').last.label, 'Pils');
  });

  test('Gleichstand wird alphabetisch aufgelöst (stabile Reihenfolge)', () {
    final stats = computeStats([
      detail(id: '1', at: now, style: 'Zwickl'),
      detail(id: '2', at: now, style: 'Alt'),
    ], now: now, period: alles);

    expect(stats.slices('style').map((s) => s.label).toList(),
        ['Alt', 'Zwickl']);
  });

  test('Verschiedene Biere, Brauereien und Orte werden einzeln gezählt', () {
    final stats = computeStats([
      detail(id: '1', at: now, venueName: 'Augustiner'),
      detail(id: '2', at: now, venueName: 'Augustiner'),
      detail(id: '3', at: now), // ohne Ort
    ], now: now, period: alles);

    expect(stats.checkins, 3);
    expect(stats.value('beers'), 3);
    expect(stats.value('breweries'), 1);
    // Ohne Ort zählt nicht mit, doppelte Orte nur einmal.
    expect(stats.value('venues'), 1);
  });

  test('Ohne Angabe erscheint als eigenes Gebinde statt zu verschwinden', () {
    final stats = computeStats([
      detail(id: '1', at: now, serving: ServingStyle.draft),
      detail(id: '2', at: now),
    ], now: now, period: alles);

    final labels = stats.slices('serving').map((s) => s.label).toList();
    expect(labels, containsAll(['vom Fass', 'ohne Angabe']));
  });

  test('Durchschnitt rechnet nur über bewertete Check-ins', () {
    final stats = computeStats([
      detail(id: '1', at: now, rating: 4),
      detail(id: '2', at: now, rating: 3),
      detail(id: '3', at: now), // unbewertet zieht nicht nach unten
    ], now: now, period: alles);

    expect(stats.value('rating'), 3.5);
  });

  test('Monate erscheinen aufsteigend und nur, wenn es sie gibt', () {
    final stats = computeStats([
      detail(id: '1', at: DateTime(2026, 8, 2)),
      detail(id: '2', at: DateTime(2026, 6, 9)),
      detail(id: '3', at: DateTime(2026, 8, 30)),
    ], now: now, period: alles);

    // Juli fehlt bewusst: kein Eintrag ist kein Nullwert.
    expect(stats.byMonth.map((s) => s.label).toList(), ['06/2026', '08/2026']);
    expect(stats.byMonth.last.count, 2);
  });

  test('Alkoholfreie werden mitgezählt', () {
    final stats = computeStats([
      detail(id: '1', at: now, alcoholFree: true),
      detail(id: '2', at: now),
    ], now: now, period: alles);

    expect(stats.value('alcoholFree'), 1);
  });

  group('Kennzahlen ohne Aussage erscheinen gar nicht', () {
    // Der Bildschirm hat keine Sonderbedingung je Kachel — eine Kennzahl,
    // die nichts zu sagen hat, liefert `null` und fällt damit weg. Wäre
    // sie stattdessen 0, stünde da „0 Orte" statt gar nichts.
    test('keine Bewertung, kein Ø', () {
      final stats = computeStats([
        detail(id: '1', at: now),
      ], now: now, period: alles);

      expect(stats.value('rating'), isNull);
      expect(stats.values.containsKey('rating'), isFalse);
    });

    test('kein Ort, keine Ortskachel', () {
      final stats = computeStats([
        detail(id: '1', at: now),
      ], now: now, period: alles);

      expect(stats.value('venues'), isNull);
    });

    test('nichts Alkoholfreies, keine Kachel', () {
      final stats = computeStats([
        detail(id: '1', at: now),
      ], now: now, period: alles);

      expect(stats.value('alcoholFree'), isNull);
    });
  });

  group('Neue Aufteilungen', () {
    test('Wochentage stehen chronologisch, nicht nach Häufigkeit', () {
      // 2026-08-10 ist ein Montag, der 14. ein Freitag.
      final stats = computeStats([
        detail(id: '1', at: DateTime(2026, 8, 14)), // Freitag
        detail(id: '2', at: DateTime(2026, 8, 14)),
        detail(id: '3', at: DateTime(2026, 8, 10)), // Montag
      ], now: now, period: alles);

      // Montag hat weniger, steht aber vorn: Ein Wochentagsdiagramm, das
      // mit Freitag beginnt, zeigt kein Muster mehr.
      expect(stats.slices('weekday').map((s) => s.label).toList(),
          ['Montag', 'Freitag']);
      expect(stats.slices('weekday').last.count, 2);
    });

    test('Region kommt aus der Stadt der Brauerei, Leeres fällt weg', () {
      final stats = computeStats([
        detail(id: '1', at: now, city: 'Salzburg'),
        detail(id: '2', at: now, city: 'Salzburg'),
        detail(id: '3', at: now, city: ''),
        detail(id: '4', at: now), // null
      ], now: now, period: alles);

      expect(stats.slices('region').length, 1);
      expect(stats.slices('region').single.label, 'Salzburg');
      expect(stats.slices('region').single.count, 2);
    });

    test('Bewertungen stehen aufsteigend, halbe Sterne mit Komma', () {
      final stats = computeStats([
        detail(id: '1', at: now, rating: 5),
        detail(id: '2', at: now, rating: 3.5),
        detail(id: '3', at: now, rating: 3.5),
        detail(id: '4', at: now), // unbewertet taucht nicht auf
      ], now: now, period: alles);

      expect(stats.slices('rating').map((s) => s.label).toList(),
          ['3,5', '5']);
    });

    test('Allein oder in Runde — beides ist eine Antwort', () {
      final stats = computeStats([
        detail(id: '1', at: now, sessionId: 's1'),
        detail(id: '2', at: now),
        detail(id: '3', at: now),
      ], now: now, period: alles);

      final nach = {
        for (final s in stats.slices('company')) s.label: s.count,
      };
      expect(nach, {'allein': 2, 'in einer Runde': 1});
    });

    test('Top-N schneidet ab, geschlossene Mengen nicht', () {
      final viele = [
        for (var i = 0; i < 15; i++)
          detail(id: '$i', at: now, style: 'Stil $i'),
      ];
      final stats = computeStats(viele, now: now, period: alles);

      expect(stats.slices('style').length, 10);
      // Gebinde ist geschlossen — hier wäre ein abgeschnittener Rest
      // irreführend.
      expect(dimensionFor('serving').top, isNull);
    });
  });

  group('Neue Kennzahlen', () {
    test('Neue Biere zählt nur, was vorher nicht dran war', () {
      final rows = [
        detail(id: 'alt', at: DateTime(2026, 1, 5)),
        detail(id: 'alt', at: DateTime(2026, 8, 2)), // dasselbe Bier
        detail(id: 'neu', at: DateTime(2026, 8, 3)),
      ];

      final stats = computeStats(rows, now: now, period: dieserMonat);
      expect(stats.value('beers'), 2, reason: 'im Monat zwei verschiedene');
      expect(stats.value('newBeers'), 1, reason: 'nur eines davon ist neu');
    });

    test('Ohne Zeitraum gibt es keine neuen Biere — die Zahl wäre eine '
        'Dublette', () {
      final stats = computeStats([
        detail(id: '1', at: now),
      ], now: now, period: alles);

      expect(stats.value('newBeers'), isNull);
    });

    test('Neu heißt neu, unabhängig vom gesetzten Filter', () {
      // Das Bier war im Januar schon dran — nur eben als „Pils". Wer jetzt
      // nach Märzen filtert, darf es nicht plötzlich als neu angezeigt
      // bekommen.
      final rows = [
        detail(id: 'x', at: DateTime(2026, 1, 5), style: 'Pils'),
        detail(id: 'x', at: DateTime(2026, 8, 3), style: 'Märzen'),
      ];

      final stats =
          computeStats(rows, now: now, period: dieserMonat, style: 'Märzen');
      expect(stats.value('newBeers'), 0);
    });

    test('Ø je Woche erst ab zwei Wochen Zeitraum', () {
      // Eine Woche alter Monat: eine Wochenrate daraus wäre geraten.
      final kurz = computeStats([
        detail(id: '1', at: DateTime(2026, 8, 5)),
      ], now: DateTime(2026, 8, 8), period: dieserMonat);
      expect(kurz.value('perWeek'), isNull,
          reason: 'eine Woche trägt keine Wochenrate');

      // Genau zwei Wochen ist die Grenze — und sie zählt schon mit.
      final grenze = computeStats([
        detail(id: '1', at: DateTime(2026, 8, 5)),
      ], now: DateTime(2026, 8, 15), period: dieserMonat);
      expect(grenze.value('perWeek'), 0.5);

      final lang = computeStats([
        for (var i = 1; i <= 10; i++) detail(id: '$i', at: DateTime(2026, 3, i)),
      ], now: DateTime(2026, 8, 15), period: diesesJahr);
      expect(lang.value('perWeek'), isNotNull);
      expect(lang.value('perWeek')!, lessThan(1));
    });
  });

  group('Vergleich mit dem Zeitraum davor', () {
    test('Der Vormonat wird mitgerechnet', () {
      final rows = [
        for (var i = 1; i <= 3; i++) detail(id: 'j$i', at: DateTime(2026, 7, i)),
        for (var i = 1; i <= 5; i++) detail(id: 'a$i', at: DateTime(2026, 8, i)),
      ];

      final stats = computeStats(rows, now: now, period: dieserMonat);
      expect(stats.checkins, 5);
      expect(stats.previous?.checkins, 3);
      // Der Vergleich selbst hat keinen eigenen Vergleich — sonst liefe
      // die Rechnung endlos in die Vergangenheit.
      expect(stats.previous?.previous, isNull);
    });

    test('Das Vorjahr wird mitgerechnet', () {
      final rows = [
        detail(id: '1', at: DateTime(2025, 4, 1)),
        detail(id: '2', at: DateTime(2026, 4, 1)),
      ];

      final stats = computeStats(rows, now: now, period: diesesJahr);
      expect(stats.checkins, 1);
      expect(stats.previous?.checkins, 1);
    });

    test('„Alles" hat kein Davor', () {
      final stats = computeStats([
        detail(id: '1', at: now),
      ], now: now, period: alles);

      expect(stats.previous, isNull);
    });

    test('Ein leerer Zeitraum behält seinen Vergleich', () {
      // „Diesen Monat noch nichts, im Vormonat waren es zwei" ist eine
      // Aussage — „nichts" allein nicht.
      final stats = computeStats([
        detail(id: '1', at: DateTime(2026, 7, 4)),
        detail(id: '2', at: DateTime(2026, 7, 5)),
      ], now: now, period: dieserMonat);

      expect(stats.isEmpty, isTrue);
      expect(stats.previous?.checkins, 2);
    });
  });

  group('Freier Zeitraum', () {
    test('Von und Bis sind beide eingeschlossen', () {
      final rows = [
        detail(id: 'vor', at: DateTime(2026, 7, 9, 23)),
        detail(id: 'start', at: DateTime(2026, 7, 10, 0, 5)),
        detail(id: 'ende', at: DateTime(2026, 7, 14, 23, 30)),
        detail(id: 'nach', at: DateTime(2026, 7, 15, 0, 30)),
      ];

      final stats = computeStats(
        rows,
        now: now,
        period: StatsPeriod.custom(DateTime(2026, 7, 10), DateTime(2026, 7, 14)),
      );

      // Wer „bis 14. Juli" wählt, meint den ganzen 14., nicht dessen
      // Mitternacht.
      expect(stats.checkins, 2);
    });

    test('Das Davor ist gleich lang und schließt direkt an', () {
      final rows = [
        detail(id: 'davor', at: DateTime(2026, 7, 6)),
        detail(id: 'drin', at: DateTime(2026, 7, 11)),
      ];

      final stats = computeStats(
        rows,
        now: now,
        period: StatsPeriod.custom(DateTime(2026, 7, 10), DateTime(2026, 7, 14)),
      );

      // 10.–14. ist fünf Tage; davor liegt 5.–9.
      expect(stats.checkins, 1);
      expect(stats.previous?.checkins, 1);
    });

    test('Beschriftung nennt beide Daten', () {
      final p = StatsPeriod.custom(
          DateTime(2026, 7, 10), DateTime(2026, 7, 14));
      expect(p.label, '10.7.2026 – 14.7.2026');
      expect(p.isCustom, isTrue);
      expect(p.preset, isNull);
    });
  });

  group('Formatierung', () {
    test('Füllmengen in deutscher Schreibweise', () {
      expect(formatVolume(330), '0,33 l');
      expect(formatVolume(500), '0,5 l');
      expect(formatVolume(1000), '1 l');
      expect(formatVolume(250), '0,25 l');
    });

    test('Liter mit einer Nachkommastelle', () {
      expect(formatLitres(12.44), '12,4 l');
      expect(formatLitres(0), '0,0 l');
    });
  });
}
