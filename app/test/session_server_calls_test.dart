import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';

import 'fake_online_service.dart';

/// Bei angemeldetem Konto muss der Server auch wirklich gerufen werden.
///
/// Das klingt trivial und ist genau der Test, der zweimal gefehlt hat:
/// Vor dem Serveraufruf stand jeweils eine Bedingung, die immer griff, der
/// Aufruf unterblieb vollständig — und die App meldete Erfolg. Beide Male
/// fiel es keinem Test auf, weil alle Tests den `onlineServiceProvider`
/// mit `null` überschrieben und damit nur den kontolosen Zweig prüften.
///
/// Diese Datei prüft das Gegenteil: dass die Aufrufe stattfinden.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    online = FakeOnlineService();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      onlineServiceProvider.overrideWith((ref) async => online),
    ]);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<String> starteBeacon() async {
    await container.read(actionsProvider).startSession(
          venueName: 'Augustiner',
          visibility: SessionVisibility.friends,
          autoEnd: const Duration(hours: 3),
        );
    final me = await db.getMe();
    final s = await db.getMyActiveSession(me.id, DateTime.now());
    return s!.id;
  }

  test('Beenden ruft den Server mit der eigenen Session-ID', () async {
    final id = await starteBeacon();
    online.aufrufe.clear();

    final ergebnis = await container.read(actionsProvider).endMySession();

    expect(ergebnis?.synced, isTrue);
    expect(ergebnis?.beendet.id, id,
        reason: 'Ohne die beendete Zeile gäbe es kein „Rückgängig".');
    expect(online.aufrufe, contains('endSession:$id'),
        reason: 'Ohne diesen Aufruf bleibt der Beacon für Freunde stehen.');
  });

  test('Scheitert der Server, meldet Beenden ehrlich false', () async {
    await starteBeacon();
    online.schlaegtFehl = true;

    expect(
        (await container.read(actionsProvider).endMySession())?.synced,
        isFalse);
  });

  test('Verlängern ruft den Server mit der eigenen Session-ID', () async {
    final id = await starteBeacon();
    online.aufrufe.clear();

    final result = await container
        .read(actionsProvider)
        .extendMySession(const Duration(hours: 2));

    expect(result, isNotNull);
    expect(result!.synced, isTrue);
    expect(online.aufrufe, contains('updateSessionExpiry:$id'));
  });

  test('Scheitert der Server, meldet Verlängern synced=false', () async {
    await starteBeacon();
    online.schlaegtFehl = true;

    final result = await container
        .read(actionsProvider)
        .extendMySession(const Duration(hours: 2));

    expect(result!.synced, isFalse,
        reason: 'Sonst glaubt der Nutzer, Freunde sähen das neue Ende.');
  });

  test('Die Abgleichroutine verschont den eigenen laufenden Beacon — und '
      'beendet Unbekanntes nicht', () async {
    final id = await starteBeacon();
    // Eine Session, die dieses Geraet nicht kennt. Frueher galt sie als
    // „haengen geblieben" und wurde beendet. Sie kann aber genauso gut vom
    // anderen Geraet desselben Menschen stammen — dann waere Beenden eine
    // Loeschung. Unbekanntes wird jetzt uebernommen, nie beendet.
    online.aktiveSessionIds.add('vom-anderen-geraet');

    final geaendert = await container.read(sessionReconcileProvider.future);

    expect(geaendert, 1, reason: 'Die fremde Zeile wurde uebernommen.');
    expect(online.aufrufe.where((a) => a.startsWith('endSession')), isEmpty,
        reason: 'Weder der eigene Beacon noch die unbekannte Session '
            'duerfen abgeraeumt werden.');
    expect(online.aufrufe, isNot(contains('endSession:$id')));
  });

  test('Ohne lokalen Beacon werden Server-Sessions uebernommen, nicht '
      'abgeraeumt', () async {
    online.aktiveSessionIds.addAll(['a', 'b']);

    final geaendert = await container.read(sessionReconcileProvider.future);

    expect(geaendert, 2);
    expect(online.aufrufe.where((a) => a.startsWith('endSession')), isEmpty,
        reason: 'Ein leeres Geraet ist kein Beweis, dass nichts laeuft — '
            'es ist nur ein zweites Geraet.');
  });
}
