import 'package:brewmates/domain/wochen_verlauf.dart';
import 'package:brewmates/widgets/wochen_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #166 — Die Wochen-Serie als Bild.
///
/// Geprüft wird die Rechnung, nicht die Optik: Wochengrenzen, die feste
/// Länge und die Behandlung von Zeitpunkten, die nicht hineinpassen. Ob
/// die Felder schön aussehen, entscheidet kein Test.
void main() {
  // Ein Mittwoch. Der Montag dieser Woche ist der 3. September 2026.
  final jetzt = DateTime(2026, 9, 5, 20, 30);

  group('wochenVerlauf', () {
    test('liefert immer genau so viele Wochen wie verlangt', () {
      expect(wochenVerlauf(const [], jetzt).length, 52);
      expect(wochenVerlauf(const [], jetzt, wochen: 12).length, 12);
      // Auch für ein Konto, das erst seit gestern existiert: Eine Fläche,
      // die mitwächst, sähe jede Woche anders aus.
      expect(wochenVerlauf([jetzt], jetzt).length, 52);
    });

    test('die laufende Woche steht am Ende, die älteste am Anfang', () {
      final v = wochenVerlauf(const [], jetzt);
      expect(v.last.montag, DateTime(2026, 8, 31));
      expect(v.first.montag, DateTime(2026, 8, 31).subtract(
        const Duration(days: 7 * 51),
      ));
    });

    test('zählt Check-ins in die Woche ihres Montags', () {
      final v = wochenVerlauf([
        DateTime(2026, 8, 31, 0, 1), // Montag früh, laufende Woche
        DateTime(2026, 9, 5, 23, 59), // Samstag spät, dieselbe Woche
        DateTime(2026, 8, 30, 23, 59), // Sonntag davor: Vorwoche
      ], jetzt);
      expect(v.last.anzahl, 2);
      expect(v[v.length - 2].anzahl, 1);
    });

    test('was aus dem Zeitraum fällt, verschwindet nicht stillschweigend',
        () {
      // Ein Zeitpunkt in der Zukunft (falsch gestellte Uhr) landet in der
      // laufenden Woche statt aus dem Bild zu fallen.
      final v = wochenVerlauf([DateTime(2027, 1, 1)], jetzt);
      expect(v.last.anzahl, 1);

      // Was älter ist als der Zeitraum, taucht schlicht nicht auf — das
      // ist gewollt, es ist ein Jahresrückblick.
      final alt = wochenVerlauf([DateTime(2020, 1, 1)], jetzt);
      expect(alt.fold<int>(0, (s, w) => s + w.anzahl), 0);
    });
  });

  group('WochenHeatmap', () {
    testWidgets('zeigt ein Feld je Woche und nennt die Bezugsgröße',
        (tester) async {
      final wochen = wochenVerlauf([
        DateTime(2026, 8, 31),
        DateTime(2026, 9, 1),
        DateTime(2026, 8, 25),
      ], jetzt, wochen: 13);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 360, child: WochenHeatmap(wochen: wochen)),
        ),
      ));

      // Zwei aktive Wochen von dreizehn, beste Woche zwei Check-ins.
      expect(
        find.text('2 von 13 Wochen mit Check-in · '
            'kräftigstes Feld = beste Woche (2)'),
        findsOneWidget,
      );
    });

    testWidgets('jedes Feld sagt vorlesbar, worum es geht', (tester) async {
      final wochen = wochenVerlauf([DateTime(2026, 8, 31)], jetzt, wochen: 2);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 360, child: WochenHeatmap(wochen: wochen)),
        ),
      ));

      // Farbe allein trägt hier die Aussage — deshalb steht sie zusätzlich
      // als Text an jedem Feld (docs/14).
      expect(
        find.bySemanticsLabel('Woche ab 31. August: 1 Check-in'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Woche ab 24. August: nichts'),
        findsOneWidget,
      );
    });

    testWidgets('ohne Wochen bleibt nichts stehen', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: WochenHeatmap(wochen: [])),
      ));
      expect(find.byType(Tooltip), findsNothing);
    });
  });
}
