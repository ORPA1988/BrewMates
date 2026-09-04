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

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';

/// Check-ins korrigieren statt wegwerfen (Funktion 27, Backlog B-6).
///
/// Der Kern ist nicht das Ändern selbst, sondern dass die Änderung den
/// Server erreicht: Der Abgleich lud bisher nur hoch, was dort **noch
/// nicht** lag. Ohne das `dirty`-Flag wäre eine Korrektur an einem bereits
/// hochgeladenen Check-in lokal sichtbar gewesen und für Freunde nie.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  late String beerId;
  late String meId;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    beerId = (await db.select(db.beers).get()).first.id;
    meId = (await db.getMe()).id;
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      onlineServiceProvider.overrideWith((ref) async => null),
    ]);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<String> checkin({double? rating, String? note}) async {
    const id = 'c-1';
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: id,
          profileId: meId,
          beerId: beerId,
          rating: Value(rating),
          note: Value(note),
          createdAt: DateTime.utc(2026, 8, 15, 20),
        ));
    return id;
  }

  test('Korrektur wirkt sofort und merkt sich den Nachtrag', () async {
    final id = await checkin(rating: 2.0, note: 'zu schnell getippt');

    final ok = await container
        .read(actionsProvider)
        .editCheckin(id, rating: 4.5, note: 'doch ganz gut');

    expect(ok, isTrue);
    final row = await db.findCheckin(id);
    expect(row!.rating, 4.5);
    expect(row.note, 'doch ganz gut');
    expect(row.dirty, isTrue,
        reason: 'Ohne die Markierung erreicht die Korrektur nie den Server.');
  });

  test('Ein Feld leeren geht nur über den ausdrücklichen Schalter', () async {
    final id = await checkin(rating: 3.0, note: 'Notiz');

    // null heißt „nicht anfassen" — sonst könnte man eine Notiz nie
    // wieder loswerden, ohne den Check-in zu löschen.
    await container.read(actionsProvider).editCheckin(id, rating: 3.5);
    expect((await db.findCheckin(id))!.note, 'Notiz');

    await container.read(actionsProvider).editCheckin(id, clearNote: true);
    expect((await db.findCheckin(id))!.note, isNull);
  });

  test('Fremde Check-ins lehnt schon die App ab', () async {
    await db.into(db.profiles).insert(ProfilesCompanion.insert(
          id: 'fremd',
          username: 'fremd',
          displayName: 'Fremd',
        ));
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: 'c-fremd',
          profileId: 'fremd',
          beerId: beerId,
          rating: const Value(1.0),
          createdAt: DateTime.utc(2026, 8, 15),
        ));

    final ok = await container
        .read(actionsProvider)
        .editCheckin('c-fremd', rating: 5.0);

    expect(ok, isFalse);
    expect((await db.findCheckin('c-fremd'))!.rating, 1.0,
        reason: 'Der Server lehnt es ohnehin ab — die App soll gar nicht '
            'erst so tun, als ginge es.');
  });

  test('Nach dem Hochladen ist die Zeile wieder sauber', () async {
    final id = await checkin(rating: 3.0);
    await container.read(actionsProvider).editCheckin(id, rating: 4.0);
    expect((await db.findCheckin(id))!.dirty, isTrue);

    await db.markCheckinsClean([id]);

    expect((await db.findCheckin(id))!.dirty, isFalse,
        reason: 'Bliebe das Flag stehen, lüde der Abgleich dieselbe Zeile '
            'bei jedem Durchlauf erneut hoch.');
  });

  test('Das Bier lässt sich nicht ändern', () async {
    // Bewusst keine API dafür: Ein anderes Bier ist ein anderer Check-in.
    // Dieser Test hält die Entscheidung fest, damit sie nicht aus
    // Bequemlichkeit aufgeweicht wird.
    final id = await checkin(rating: 3.0);
    final vorher = (await db.findCheckin(id))!.beerId;
    await container.read(actionsProvider).editCheckin(id, rating: 4.0);
    expect((await db.findCheckin(id))!.beerId, vorher);
  });
}
