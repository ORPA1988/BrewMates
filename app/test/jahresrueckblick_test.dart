import 'package:brewmates/core/checkin_facts.dart';
import 'package:brewmates/domain/jahresrueckblick.dart';
import 'package:flutter_test/flutter_test.dart';

/// #167 — Dein Bierjahr in Zahlen.
///
/// Geprüft wird die Rechnung. Ob das Bild schön ist, entscheidet kein
/// Test; ob „zum ersten Mal" wirklich das erste Mal war, schon.
CheckinFacts _c(
  DateTime wann, {
  String bier = 'b1',
  String bierName = 'Testbier',
  String stil = 'Märzen',
  String brauerei = 'br1',
  String? session,
  String? ort,
}) =>
    CheckinFacts(
      createdAt: wann,
      beerId: bier,
      beerName: bierName,
      beerStyle: stil,
      isAlcoholFree: false,
      breweryId: brauerei,
      breweryName: 'Testbrauerei',
      breweryCountry: 'AT',
      sessionId: session,
      venueId: ort,
    );

String? _wert(Jahresrueckblick r, String beschriftung) {
  for (final z in r.zeilen) {
    if (z.beschriftung == beschriftung) return z.wert;
  }
  return null;
}

void main() {
  test('ein Jahr ohne Check-ins ist leer, nicht falsch', () {
    final r = jahresrueckblick([_c(DateTime(2025, 5, 1))], 2026);
    expect(r.istLeer, isTrue);
    expect(r.zeilen, isEmpty);
    // Die Fläche kommt trotzdem — die Oberfläche entscheidet, ob sie sie
    // zeigt, nicht die Rechnung.
    expect(r.wochen.length, 53);
  });

  test('zählt nur das gewählte Jahr', () {
    final r = jahresrueckblick([
      _c(DateTime(2025, 12, 31, 23, 59)),
      _c(DateTime(2026, 1, 1, 0, 1)),
      _c(DateTime(2026, 6, 1)),
      _c(DateTime(2027, 1, 1)),
    ], 2026);
    expect(r.checkins, 2);
  });

  test('„zum ersten Mal" braucht die Jahre davor', () {
    final alle = [
      _c(DateTime(2025, 3, 1), bier: 'alt'),
      _c(DateTime(2026, 3, 1), bier: 'alt'),
      _c(DateTime(2026, 4, 1), bier: 'neu'),
    ];
    // Ein Bier ist nicht dadurch neu, dass das Jahr neu ist.
    expect(_wert(jahresrueckblick(alle, 2026), 'zum ersten Mal'), '1');

    // Und wer nur die Zeilen des Jahres hineingibt, bekäme zwei — genau
    // der Fehler, den die Signatur verhindern soll.
    final nurDiesesJahr = alle.where((c) => c.createdAt.year == 2026);
    expect(_wert(jahresrueckblick(nurDiesesJahr, 2026), 'zum ersten Mal'), '2');
  });

  test('das Lieblingsbier ist bei Gleichstand nicht zufällig', () {
    // Zweimal A, zweimal B: alphabetisch entscheidet, damit derselbe
    // Rückblick beim zweiten Öffnen nicht anders aussieht.
    final r1 = jahresrueckblick([
      _c(DateTime(2026, 1, 5), bier: 'a', bierName: 'Anton'),
      _c(DateTime(2026, 1, 6), bier: 'b', bierName: 'Berta'),
      _c(DateTime(2026, 1, 7), bier: 'b', bierName: 'Berta'),
      _c(DateTime(2026, 1, 8), bier: 'a', bierName: 'Anton'),
    ], 2026);
    final r2 = jahresrueckblick([
      _c(DateTime(2026, 1, 8), bier: 'b', bierName: 'Berta'),
      _c(DateTime(2026, 1, 7), bier: 'a', bierName: 'Anton'),
      _c(DateTime(2026, 1, 6), bier: 'a', bierName: 'Anton'),
      _c(DateTime(2026, 1, 5), bier: 'b', bierName: 'Berta'),
    ], 2026);
    expect(_wert(r1, 'am häufigsten im Glas'), 'Anton');
    expect(_wert(r2, 'am häufigsten im Glas'), 'Anton');
  });

  test('Runden und Orte werden je einmal gezählt', () {
    final r = jahresrueckblick([
      _c(DateTime(2026, 2, 1), session: 's1', ort: 'v1'),
      _c(DateTime(2026, 2, 1), session: 's1', ort: 'v1'),
      _c(DateTime(2026, 2, 2), session: 's2', ort: 'v2'),
      _c(DateTime(2026, 2, 3)),
    ], 2026);
    expect(_wert(r, 'Runden mit anderen'), '2');
    expect(_wert(r, 'verschiedene Orte'), '2');
  });

  test('die längste Serie ist die längste, nicht die letzte', () {
    // Drei Wochen am Stück im Frühjahr, danach eine einzelne.
    final r = jahresrueckblick([
      _c(DateTime(2026, 3, 2)),
      _c(DateTime(2026, 3, 9)),
      _c(DateTime(2026, 3, 16)),
      _c(DateTime(2026, 11, 2)),
    ], 2026);
    expect(_wert(r, 'Wochen am Stück'), '3');
  });

  test('eine einzelne Woche ist keine Serie', () {
    final r = jahresrueckblick([_c(DateTime(2026, 3, 2))], 2026);
    expect(_wert(r, 'Wochen am Stück'), isNull);
  });

  test('Einzahl und Mehrzahl stimmen', () {
    final einer = jahresrueckblick([_c(DateTime(2026, 3, 2), ort: 'v1')], 2026);
    expect(einer.zeilen.first.beschriftung, 'Check-in');
    expect(_wert(einer, 'Ort'), '1');
  });

  test('rueckblickJahre liefert das neueste zuerst und jedes einmal', () {
    expect(
      rueckblickJahre([
        _c(DateTime(2024, 1, 1)),
        _c(DateTime(2026, 1, 1)),
        _c(DateTime(2024, 6, 1)),
      ]),
      [2026, 2024],
    );
    expect(rueckblickJahre(const []), isEmpty);
  });
}
