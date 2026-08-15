import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';

/// Gebindegröße je Barcode und Nachtragen einer EAN an ein vorhandenes
/// Bier.
///
/// Der fachliche Kern: **Eine EAN bezeichnet nicht das Bier, sondern die
/// Handelseinheit.** Dieselbe Marke in 0,33 und 0,5 trägt zwei
/// verschiedene Nummern. Daraus folgt beides — dass ein Bier mehrere
/// Barcodes hat, und dass die Größe an den Code gehört und nicht ans Bier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late String beerId;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    beerId = (await db.select(db.beers).get()).first.id;
  });

  tearDown(() => db.close());

  group('Barcode an ein vorhandenes Bier hängen', () {
    test('Ein neuer Code kommt dazu, ohne die alten zu verlieren', () async {
      final vorher = (await db.findBeerByBarcode('90034107'))?.beer;
      // Wir nehmen ein Bier mit bekannten Codes, damit „dazu" auch etwas
      // heißt.
      final ziel = vorher ?? (await db.select(db.beers).get())
          .firstWhere((b) => b.barcodes.isNotEmpty);
      final alteCodes = ziel.barcodes.split(',').where((c) => c.isNotEmpty);

      expect(await db.addBarcodeToBeer(ziel.id, '1234567890123'), isTrue);

      final danach = await db.findBeerByBarcode('1234567890123');
      expect(danach, isNotNull);
      expect(danach!.beer.id, ziel.id);
      for (final alt in alteCodes) {
        expect(await db.findBeerByBarcode(alt.trim()), isNotNull,
            reason: 'Der bestehende Code $alt darf nicht verloren gehen.');
      }
    });

    test('Derselbe Code zweimal ändert nichts', () async {
      await db.addBarcodeToBeer(beerId, '1234567890123');
      expect(await db.addBarcodeToBeer(beerId, '1234567890123'), isFalse,
          reason: 'Kein Fehler — es gibt nur nichts zu tun.');
    });

    test('Ein unbekanntes Bier lässt sich nicht ergänzen', () async {
      expect(await db.addBarcodeToBeer('gibt-es-nicht', '1234567890123'),
          isFalse);
    });
  });

  group('Gebindegröße am Barcode', () {
    test('Gemerkte Größe wird zum Code zurückgegeben', () async {
      await db.setBarcodeVolume('1234567890123', 330);
      expect(await db.barcodeVolume('1234567890123'), 330);
    });

    test('Unbekannter Code liefert null, keine geratene Größe', () async {
      // null heißt „nicht erfasst". Die Auswertung schätzt dann nach
      // Gebinde und weist das aus — eine erfundene Zahl wäre schlimmer.
      expect(await db.barcodeVolume('9999999999999'), isNull);
    });

    test('Eine Korrektur überschreibt, ohne vorher zu löschen', () async {
      await db.setBarcodeVolume('1234567890123', 500);
      await db.setBarcodeVolume('1234567890123', 330);
      expect(await db.barcodeVolume('1234567890123'), 330);
    });

    test('Zwei Codes desselben Biers tragen verschiedene Größen', () async {
      // Das ist der ganze Punkt: Der Barcode unterscheidet 0,33 von 0,5.
      await db.addBarcodeToBeer(beerId, '1111111111111');
      await db.addBarcodeToBeer(beerId, '2222222222222');
      await db.setBarcodeVolume('1111111111111', 330);
      await db.setBarcodeVolume('2222222222222', 500);

      expect(await db.barcodeVolume('1111111111111'), 330);
      expect(await db.barcodeVolume('2222222222222'), 500);
      expect((await db.findBeerByBarcode('1111111111111'))!.beer.id,
          (await db.findBeerByBarcode('2222222222222'))!.beer.id,
          reason: 'Beide Codes gehören zum selben Bier.');
    });
  });
}
