// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/checkin_delete_queue.dart';
import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late String beerId;
  late String myId;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    beerId = (await db.select(db.beers).get()).first.id;
    myId = (await db.getMe()).id;
  });

  tearDown(() => db.close());

  Future<String> addCheckin({String? photoUrl, String? id}) async {
    final checkinId = id ?? 'c-${DateTime.now().microsecondsSinceEpoch}';
    await db.into(db.checkins).insert(CheckinsCompanion.insert(
          id: checkinId,
          profileId: myId,
          beerId: beerId,
          photoUrl: Value(photoUrl),
          createdAt: DateTime.utc(2026, 8, 15, 20),
        ));
    return checkinId;
  }

  test('Löschen entfernt lokal sofort und merkt es für den Server',
      () async {
    final id = await addCheckin(photoUrl: 'https://x/beer-photos/$myId/a.jpg');

    await db.deleteCheckinLocal(
      id,
      photoUrl: 'https://x/beer-photos/$myId/a.jpg',
      now: DateTime.utc(2026, 8, 15, 21),
    );

    expect(await db.findCheckin(id), isNull);
    final pending = await db.pendingCheckinDeletes();
    expect(pending, hasLength(1));
    expect(pending.single.checkinId, id);
    expect(pending.single.photoUrl, contains('a.jpg'));
  });

  test('Toasts und Kommentare verschwinden mit dem Check-in', () async {
    final id = await addCheckin();
    await db.into(db.toasts).insert(
        ToastsCompanion.insert(checkinId: id, profileId: myId));
    await db.into(db.comments).insert(CommentsCompanion.insert(
          id: 'k1',
          checkinId: id,
          profileId: myId,
          body: 'Prost',
          createdAt: DateTime.utc(2026, 8, 15, 20, 5),
        ));

    await db.deleteCheckinLocal(id, now: DateTime.utc(2026, 8, 15, 21));

    expect(await db.select(db.toasts).get(), isEmpty);
    expect(await db.select(db.comments).get(), isEmpty);
  });

  test('Replay überträgt FIFO, löscht das Foto und leert die Queue',
      () async {
    final first = await addCheckin(id: 'c1', photoUrl: 'p1');
    final second = await addCheckin(id: 'c2');
    await db.deleteCheckinLocal(first,
        photoUrl: 'p1', now: DateTime.utc(2026, 8, 15, 21));
    await db.deleteCheckinLocal(second, now: DateTime.utc(2026, 8, 15, 22));

    final deleted = <String>[];
    final photos = <String>[];
    final replayed = await replayCheckinDeleteQueue(
      db,
      deleteRemote: (id) async {
        deleted.add(id);
        return null;
      },
      deletePhoto: (url) async => photos.add(url),
    );

    expect(replayed, 2);
    expect(deleted, ['c1', 'c2']);
    // Nur der erste Check-in hatte ein Bild.
    expect(photos, ['p1']);
    expect(await db.pendingCheckinDeletes(), isEmpty);
  });

  test('Verbindungsfehler bricht ab – der Rest bleibt liegen', () async {
    await db.deleteCheckinLocal(await addCheckin(id: 'c1'),
        now: DateTime.utc(2026, 8, 15, 21));
    await db.deleteCheckinLocal(await addCheckin(id: 'c2'),
        now: DateTime.utc(2026, 8, 15, 22));

    final replayed = await replayCheckinDeleteQueue(
      db,
      deleteRemote: (id) async =>
          id == 'c1' ? null : 'Keine Verbindung – wird später übertragen.',
      deletePhoto: (_) async {},
    );

    expect(replayed, 1);
    expect(await db.pendingCheckinDeletes(), hasLength(1));
  });

  test('Fachlicher Fehler verwirft den Eintrag statt zu blockieren',
      () async {
    await db.deleteCheckinLocal(await addCheckin(id: 'c1'),
        now: DateTime.utc(2026, 8, 15, 21));

    final replayed = await replayCheckinDeleteQueue(
      db,
      deleteRemote: (_) async => 'Löschen fehlgeschlagen.',
      deletePhoto: (_) async {},
    );

    expect(replayed, 0);
    expect(await db.pendingCheckinDeletes(), isEmpty);
  });

  test('Fehler beim Foto lässt die Löschung trotzdem gelten', () async {
    await db.deleteCheckinLocal(await addCheckin(id: 'c1', photoUrl: 'p1'),
        photoUrl: 'p1', now: DateTime.utc(2026, 8, 15, 21));

    final replayed = await replayCheckinDeleteQueue(
      db,
      deleteRemote: (_) async => null,
      deletePhoto: (_) async => throw Exception('Bucket weg'),
    );

    expect(replayed, 1);
    expect(await db.pendingCheckinDeletes(), isEmpty);
  });

  test('Rückgängig stellt den Check-in wieder her und stoppt die Übertragung',
      () async {
    final id = await addCheckin(id: 'c1');
    final row = await db.findCheckin(id);
    await db.deleteCheckinLocal(id, now: DateTime.utc(2026, 8, 15, 21));

    await db.cancelCheckinDelete(id);
    await db.restoreCheckinRow(row!);

    expect(await db.findCheckin(id), isNotNull);
    expect(await db.pendingCheckinDeletes(), isEmpty);
  });

  test('Wiederholtes Abspielen schadet nicht (idempotent)', () async {
    await db.deleteCheckinLocal(await addCheckin(id: 'c1'),
        now: DateTime.utc(2026, 8, 15, 21));

    Future<int> run() => replayCheckinDeleteQueue(
          db,
          deleteRemote: (_) async => null,
          deletePhoto: (_) async {},
        );

    expect(await run(), 1);
    expect(await run(), 0);
    expect(await db.pendingCheckinDeletes(), isEmpty);
  });
}
