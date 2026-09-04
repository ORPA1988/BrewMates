// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.memory();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      onlineServiceProvider.overrideWith((ref) async => null),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('One-Tap-Nochmal: ohne bisherigen Check-in passiert nichts', () async {
    final result =
        await container.read(actionsProvider).repeatLastCheckin();
    expect(result, isNull);
    expect(await db.select(db.checkins).get(), isEmpty);
  });

  test('One-Tap-Nochmal wiederholt das zuletzt getrunkene Bier', () async {
    await db.into(db.breweries).insert(BreweriesCompanion.insert(
        id: 'b1', name: 'Testbrauerei', country: 'AT', city: 'Wien'));
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'beer-alt', breweryId: 'b1', name: 'Altes Bier', style: 'Lager'));
    await db.into(db.beers).insert(BeersCompanion.insert(
        id: 'beer-neu', breweryId: 'b1', name: 'Neues Bier',
        style: 'Pale Ale'));

    // Direkt einfügen mit expliziten Zeitstempeln — Drift speichert
    // createdAt sekundengenau, zwei createCheckin-Aufrufe in derselben
    // Sekunde hätten keine stabile Reihenfolge.
    final me = await db.getMe();
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'c-alt',
          profileId: me.id,
          beerId: 'beer-alt',
          rating: const Value(3.5),
          createdAt: DateTime(2026, 8, 1, 18),
        ));
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'c-neu',
          profileId: me.id,
          beerId: 'beer-neu',
          servingStyle: const Value(ServingStyle.draft),
          createdAt: DateTime(2026, 8, 2, 19),
        ));

    final actions = container.read(actionsProvider);
    final result = await actions.repeatLastCheckin();
    expect(result, isNotNull);
    final (name, _) = result!;
    expect(name, 'Neues Bier'); // das JÜNGSTE Bier wird wiederholt

    final all = await db.select(db.checkins).get();
    expect(all, hasLength(3));
    final mine = await db.myCheckinsDetailed(me.id);
    final repeated = mine.first;
    expect(repeated.beer.id, 'beer-neu');
    // Schnell-Log: Ausschankart wird übernommen, Bewertung bleibt offen.
    expect(repeated.checkin.servingStyle, ServingStyle.draft);
    expect(repeated.checkin.rating, isNull);
  });
}
