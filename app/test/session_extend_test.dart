import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';

/// Verlängern meldet ehrlich, ob der Server es mitbekommen hat.
///
/// Vorher gab `extendMySession` nur das neue Ende zurück und schickte den
/// Serveraufruf per `unawaited` ins Leere — schlug er fehl, sah der Nutzer
/// trotzdem „Beacon läuft noch 3 h", während Freunde weiter das alte Ende
/// angezeigt bekamen. Wer glaubt, er sei sichtbar, sitzt dann vergeblich
/// im Wirtshaus.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      // Kein Konto: Die Session lebt nur lokal.
      onlineServiceProvider.overrideWith((ref) async => null),
    ]);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  test('Ohne laufende Session gibt es nichts zu verlängern', () async {
    final result =
        await container.read(actionsProvider).extendMySession(
              const Duration(hours: 2),
            );
    expect(result, isNull);
  });

  test('Rein lokale Session gilt als abgeglichen, nicht als Fehlschlag',
      () async {
    // Ohne Konto gibt es keinen Server-Zwilling. „Nicht hochgeladen" wäre
    // hier eine Falschmeldung — der Nutzer hat nichts falsch gemacht.
    final me = await db.getMe();
    await container.read(actionsProvider).startSession(
          venueName: 'Augustiner',
          visibility: SessionVisibility.friends,
          autoEnd: const Duration(hours: 3),
        );

    final result = await container
        .read(actionsProvider)
        .extendMySession(const Duration(hours: 2));

    expect(result, isNotNull);
    expect(result!.synced, isTrue);

    // Und das Ende ist wirklich neu gesetzt, nicht nur zurückgemeldet.
    final session = await db.getMyActiveSession(me.id, DateTime.now());
    expect(session, isNotNull);
    expect(
      session!.expiresAt.difference(result.until).abs() <
          const Duration(seconds: 2),
      isTrue,
      reason: 'Das gemeldete Ende muss dem gespeicherten entsprechen.',
    );
  });

  test('Verlängern rechnet ab jetzt und deckelt auf die Obergrenze',
      () async {
    await container.read(actionsProvider).startSession(
          venueName: 'Stiegl-Keller',
          visibility: SessionVisibility.friends,
          autoEnd: const Duration(hours: 3),
        );

    final vorher = DateTime.now();
    final result = await container
        .read(actionsProvider)
        .extendMySession(const Duration(days: 365));

    expect(result, isNotNull);
    // Gerechnet ab jetzt, nicht ab dem bisherigen Ende — und gedeckelt.
    final laufzeit = result!.until.difference(vorher);
    expect(laufzeit <= maxSessionDuration + const Duration(seconds: 2), isTrue);
    expect(laufzeit >= maxSessionDuration - const Duration(seconds: 2), isTrue);
  });
}
