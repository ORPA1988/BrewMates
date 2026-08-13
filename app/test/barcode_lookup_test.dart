import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/features/scan/barcode_lookup.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() => db.close());

  Future<void> insertBeerWithBarcode(String id, String barcodes) async {
    final brewery = (await db.select(db.breweries).get()).first;
    await db.into(db.beers).insert(BeersCompanion.insert(
          id: id,
          breweryId: brewery.id,
          name: 'Barcode-Testbier $id',
          style: 'Helles',
          barcodes: Value(barcodes),
        ));
  }

  test('isValidEan akzeptiert nur 8 oder 13 Ziffern', () {
    expect(BarcodeLookup.isValidEan('90034107'), isTrue);
    expect(BarcodeLookup.isValidEan('9003400304939'), isTrue);
    expect(BarcodeLookup.isValidEan('1234'), isFalse);
    expect(BarcodeLookup.isValidEan('123456789012'), isFalse);
    expect(BarcodeLookup.isValidEan('9003410a'), isFalse);
  });

  test('Lokaler Treffer gewinnt – ohne Netzwerkzugriff', () async {
    await insertBeerWithBarcode('local-hit', '90034107,9001234500000');
    var networkCalled = false;
    final lookup = BarcodeLookup(db, client: MockClient((_) async {
      networkCalled = true;
      return http.Response('{}', 500);
    }));

    final result = await lookup.lookup('90034107');
    expect(result, isA<LocalBeerFound>());
    expect((result as LocalBeerFound).beer.beer.id, 'local-hit');
    expect(networkCalled, isFalse);
  });

  test('EAN-8 matcht nicht als Teilstring eines EAN-13', () async {
    // Enthält '90034107' als Präfix eines längeren Codes.
    await insertBeerWithBarcode('substring-trap', '9003410712345');
    final lookup = BarcodeLookup(db, client: MockClient((_) async =>
        http.Response('{"status":0,"status_verbose":"product not found"}',
            200)));

    final result = await lookup.lookup('90034107');
    expect(result, isA<BarcodeUnknown>(),
        reason: 'Präfix-Treffer darf nicht als exakter Barcode zählen');
  });

  test('Open-Food-Facts-Treffer liefert Name und Marke', () async {
    http.BaseRequest? seenRequest;
    final lookup = BarcodeLookup(db, client: MockClient((request) async {
      seenRequest = request;
      return http.Response(
        '{"status":1,"product":{"code":"90034107",'
        '"product_name":"Stiegl Goldbräu","brands":"Stiegl,Brau Union"}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final result = await lookup.lookup('90034107');
    expect(result, isA<OffProductFound>());
    final off = result as OffProductFound;
    expect(off.name, 'Stiegl Goldbräu');
    expect(off.brand, 'Stiegl');
    expect(off.ean, '90034107');
    expect(seenRequest?.url.path, contains('90034107'));
    expect(seenRequest?.headers['User-Agent'], BarcodeLookup.userAgent);
  });

  test('OFF „not found" → BarcodeUnknown', () async {
    final lookup = BarcodeLookup(db, client: MockClient((_) async =>
        http.Response('{"status":0,"status_verbose":"product not found"}',
            200)));
    expect(await lookup.lookup('99999999'), isA<BarcodeUnknown>());
  });

  test('Netzwerkfehler → BarcodeUnknown statt Exception', () async {
    final lookup = BarcodeLookup(db, client: MockClient((_) async {
      throw http.ClientException('offline');
    }));
    final result = await lookup.lookup('99999999');
    expect(result, isA<BarcodeUnknown>());
    expect((result as BarcodeUnknown).ean, '99999999');
  });
}
