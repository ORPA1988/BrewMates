import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/widgets/beer_thumbnail.dart';

/// Vorschaubilder statt des immer gleichen 🍺.
///
/// **Was hier geprüft wird und was nicht.** Ein echtes Bild zu laden geht
/// im Widget-Test nicht: `Image.network` bekommt vom Testrahmen auf jede
/// Anfrage einen 400er (die Warnung dazu steht in jedem Lauf). Genau das
/// macht den wichtigsten Fall aber prüfbar — **den Fehlschlag**. Und der
/// ist hier der Normalfall, nicht die Ausnahme: Die Bilder liegen auf
/// fremden Servern und können jederzeit verschwinden.
///
/// Der Rest ist Verzweigung: kein Bild → Emoji, alkoholfrei → 💧.
void main() {
  Future<void> zeige(WidgetTester tester, Widget kind) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: kind)));
    await tester.pump();
  }

  testWidgets('Ohne Bildadresse steht das vertraute Emoji da',
      (tester) async {
    await zeige(
      tester,
      const BeerThumbnail(imageUrl: null, isAlcoholFree: false),
    );
    expect(find.text('🍺'), findsOneWidget);
    expect(find.byType(Image), findsNothing,
        reason: 'Ohne Adresse darf gar nichts geladen werden.');
  });

  testWidgets('Alkoholfrei bleibt am Wassertropfen erkennbar',
      (tester) async {
    await zeige(
      tester,
      const BeerThumbnail(imageUrl: null, isAlcoholFree: true),
    );
    expect(find.text('💧'), findsOneWidget);
  });

  testWidgets('Eine leere Adresse zählt wie keine', (tester) async {
    await zeige(
      tester,
      const BeerThumbnail(imageUrl: '', isAlcoholFree: false),
    );
    expect(find.text('🍺'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('Lädt das Bild nicht, bleibt das Emoji — kein grauer Kasten',
      (tester) async {
    await zeige(
      tester,
      const BeerThumbnail(
        imageUrl: 'https://example.invalid/etikett.jpg',
        isAlcoholFree: false,
      ),
    );
    // Erst der Platzhalter …
    expect(find.text('🍺'), findsOneWidget);

    // … und nach dem gescheiterten Abruf immer noch. Ein Bild auf einem
    // fremden Server kann jederzeit weg sein; die Liste darf davon nicht
    // löchrig werden.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('🍺'), findsOneWidget);
  });

  testWidgets('Das Seitenverhältnis wird nicht gestaucht', (tester) async {
    // Der Fehler der ersten Fassung: `cacheWidth` UND `cacheHeight` auf
    // denselben Wert. Das entschlüsselt auf ein Quadrat — und staucht
    // jedes Etikett, das keins ist. Flaschen sind hoch, also praktisch
    // alle.
    //
    // Prüfbar ist das ohne echtes Bild: `Image.network` mit
    // Cache-Vorgaben baut einen `ResizeImage`, und dessen Felder sagen,
    // worauf entschlüsselt wird.
    await zeige(
      tester,
      const BeerThumbnail(
        imageUrl: 'https://example.invalid/etikett.jpg',
        isAlcoholFree: false,
      ),
    );
    final bild = tester.widget<Image>(find.byType(Image));
    final quelle = bild.image;
    expect(quelle, isA<ResizeImage>());
    final skaliert = quelle as ResizeImage;
    expect(skaliert.width, isNotNull, reason: 'Die Breite begrenzt den '
        'Speicher — ein 1000er Etikett für 40 Punkte wäre Verschwendung.');
    expect(skaliert.height, isNull,
        reason: 'Wird auch die Höhe vorgegeben, entsteht ein Quadrat und '
            'das Bild wird gestaucht.');
    expect(bild.fit, BoxFit.contain,
        reason: 'Lieber das ganze Etikett kleiner als ein Ausschnitt, '
            'bei dem der Namenszug fehlt.');
  });

  testWidgets('Die Größe wird eingehalten', (tester) async {
    await zeige(
      tester,
      const BeerThumbnail(imageUrl: null, isAlcoholFree: false, size: 48),
    );
    expect(tester.getSize(find.byType(BeerThumbnail)), const Size(48, 48));
  });
}
