import 'package:brewmates/widgets/foto_flaeche.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Meldung #171: Auf einem breiten Browserfenster war vom Foto fast
/// nichts mehr zu sehen — feste Höhe, freie Breite, also ein Streifen.
///
/// Was diese Tests festhalten, ist deshalb nicht „das Foto sieht gut
/// aus" (das kann kein Test), sondern die eine Eigenschaft, deren Fehlen
/// den Fehler ausgemacht hat: **Das Seitenverhältnis bleibt gleich, egal
/// wie breit das Fenster ist.**
void main() {
  Future<Size> groesse(WidgetTester tester, double breite) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: breite,
            child: const FotoFlaeche(child: ColoredBox(color: Colors.red)),
          ),
        ),
      ),
    );
    return tester.getSize(
      find.descendant(
        of: find.byType(FotoFlaeche),
        matching: find.byType(ClipRRect),
      ),
    );
  }

  testWidgets('Das Foto behält sein Seitenverhältnis, schmal wie breit',
      (tester) async {
    final schmal = await groesse(tester, 350);
    expect(schmal.width, 350);
    expect(schmal.height, closeTo(350 / 1.6, 0.5));

    // Der eigentliche Fehler: Vorher blieben es hier 200 Punkte Höhe auf
    // 900 Punkten Breite — ein Verhältnis von 4,5 : 1.
    final breit = await groesse(tester, 900);
    expect(breit.width / breit.height, closeTo(1.6, 0.01));
  });

  testWidgets('Breiter als der Deckel wird das Foto nicht', (tester) async {
    final breit = await groesse(tester, 1400);
    expect(breit.width, 480);
    expect(breit.height, closeTo(300, 0.5));
  });

  testWidgets('Der Eckknopf sitzt am Foto, nicht am Fensterrand',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            child: FotoFlaeche(
              ecke: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {},
              ),
              child: const ColoredBox(color: Colors.red),
            ),
          ),
        ),
      ),
    );
    final foto = tester.getRect(
      find.descendant(
        of: find.byType(FotoFlaeche),
        matching: find.byType(ClipRRect),
      ),
    );
    final knopf = tester.getRect(find.byType(IconButton));
    // Innerhalb der Fotofläche — und damit weit links vom Fensterrand.
    expect(knopf.right, lessThanOrEqualTo(foto.right));
    expect(knopf.right, lessThan(600));
  });
}
