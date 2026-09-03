import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/widgets/rating_stars.dart';

/// Was eine Vorlesehilfe von der App hört.
///
/// **Der Befund, der dazu geführt hat:** Die App hatte keine einzige
/// `Semantics`-Angabe. Bei den meisten Widgets ist das in Ordnung — ein
/// `ListTile` mit Text spricht für sich. Bei den Sternen war es das
/// nicht: TalkBack las „Stern, Stern, Halber Stern, Rahmen Stern, Rahmen
/// Stern". Technisch richtig, als Bewertung wertlos.
///
/// Die Sterne stehen an jeder Bewertung in der App — Feed, Tagebuch,
/// Bier-Detail, Scan-Treffer. Eine Stelle, viele Bildschirme.
void main() {
  Future<String?> vorgelesen(WidgetTester tester, double bewertung) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RatingStars(rating: bewertung)),
    ));
    final knoten = tester.getSemantics(find.byType(RatingStars));
    final label = knoten.label;
    handle.dispose();
    return label;
  }

  testWidgets('Aus fünf Symbolen wird ein Satz', (tester) async {
    expect(await vorgelesen(tester, 3.5), '3,5 von 5 Sternen');
  });

  testWidgets('Ganze Zahlen ohne Nachkommastelle', (tester) async {
    expect(await vorgelesen(tester, 4), '4 von 5 Sternen');
  });

  testWidgets('Komma statt Punkt — die App spricht deutsch',
      (tester) async {
    final label = await vorgelesen(tester, 2.25);
    expect(label, contains(','));
    expect(label, isNot(contains('.')));
  });

  testWidgets('Die einzelnen Sterne werden nicht mehr einzeln gelesen',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RatingStars(rating: 3)),
    ));
    // Kein Kind-Knoten mehr, der „Stern" sagt: Die Symbole sind
    // ausgeblendet, der Satz steht an ihrer Stelle.
    expect(tester.getSemantics(find.byType(RatingStars)).childrenCount, 0);
    handle.dispose();
  });
}
