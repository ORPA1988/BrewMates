// Diese Datei baut ihre Daten mit `AppDatabase.memory()` auf. Die gibt
// es nur auf der VM: Im Browser wirft `data/db/connection/web.dart`
// dort `UnsupportedError` — dort läuft Drift über sqlite3.wasm, und
// eine In-Memory-Variante davon müsste der Testlauf erst laden.
// Begründung und nächster Schritt: docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/beers/add_beer_screen.dart';
import 'package:brewmates/widgets/suggest_list.dart';

import 'fake_online_service.dart';

/// Live-Vorschläge beim Anlegen eines Bieres.
///
/// Der Zweck ist **nicht** Tipparbeit. Er ist Duplikatvermeidung: Zwei
/// Einträge für dasselbe Bier trennen Bewertungen, Abzeichen und
/// Statistik dauerhaft, und im Moment des Anlegens merkt es niemand.
/// Deshalb prüfen die Tests vor allem, dass das Antippen eines
/// Vorschlags **kein zweites Bier anlegt**.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FakeOnlineService online;

  setUp(() async {
    db = AppDatabase.memory();
    online = FakeOnlineService();
    // Zwei Biere derselben Marke — genau der Fall aus der Anforderung:
    // „Baumg" soll beide anbieten.
    final brauerei = await db.getOrCreateBrewery(
      id: 'br-baumgartner',
      name: 'Brauerei Baumgartner',
      country: 'Österreich',
      city: 'Schärding',
    );
    await db.addBeer(
      id: 'b-maerzen',
      breweryId: brauerei.id,
      name: 'Baumgartner Märzen',
      style: 'Märzen',
    );
    await db.addBeer(
      id: 'b-pils',
      breweryId: brauerei.id,
      name: 'Baumgartner Pils',
      style: 'Pils',
    );
  });

  /// Der Bildschirm laeuft unter einem echten [GoRouter].
  ///
  /// Zwei Gruende: Er schliesst sich nach dem Nachtragen eines Barcodes
  /// selbst (als einzige Route gaebe es nichts, wohin — der Test bliebe
  /// haengen), und er schickt den Menschen zur Bierseite, wenn das Bier
  /// schon existiert. Ohne Router waere genau der Weg untestbar, auf dem
  /// zuletzt das Duplikat entstand.
  Widget umgebung({String? ean}) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineServiceProvider.overrideWith((ref) async => online),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: ElevatedButton(
                        onPressed: () => context.push('/beers/add'),
                        child: const Text('Bier anlegen'),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/beers/add',
                builder: (_, __) => AddBeerScreen(initialBarcode: ean),
              ),
              GoRoute(
                path: '/beer/:id',
                builder: (_, state) => Scaffold(
                  body: Text('Bierseite ${state.pathParameters['id']}'),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> oeffnen(WidgetTester tester, {String? ean}) async {
    await tester.pumpWidget(umgebung(ean: ean));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bier anlegen'));
    await tester.pumpAndSettle();
  }

  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  /// Tippen und die Entprellung abwarten.
  Future<void> tippen(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextFormField).first, text);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('„Baumg" schlägt beide Baumgartner-Biere an', (tester) async {
    await oeffnen(tester);

    await tippen(tester, 'Baumg');

    expect(find.text('Baumgartner Märzen'), findsOneWidget);
    expect(find.text('Baumgartner Pils'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Ein einzelner Buchstabe schlägt nichts vor', (tester) async {
    await oeffnen(tester);

    await tippen(tester, 'B');

    // Ein Buchstabe passt auf fast alles. Eine Liste, die dann aufklappt,
    // verdeckt nur das Formular.
    expect(find.byType(SuggestList), findsOneWidget);
    expect(find.text('Baumgartner Pils'), findsNothing);
    expect(online.aufrufe.where((a) => a.startsWith('searchCommunityBeers')),
        isEmpty);
    await abbauen(tester);
  });

  testWidgets('Antippen trägt den Barcode nach, statt ein zweites Bier '
      'anzulegen', (tester) async {
    await oeffnen(tester, ean: '9001234567890');

    await tippen(tester, 'Baumg');
    await tester.tap(find.text('Baumgartner Märzen'));
    await tester.pumpAndSettle();

    // Der Kern der Funktion: Es bleiben zwei Biere, nicht drei.
    // Direkt abfragen statt `watchBeers().first`: Ein Drift-Stream haelt
    // die Datenbank offen, und `db.close()` im Abbau wartet dann ewig.
    final alle = await db.select(db.beers).get();
    expect(alle.length, 2, reason: 'Ein Vorschlag darf kein Duplikat anlegen.');

    final getroffen = await db.findBeerByBarcode('9001234567890');
    expect(getroffen?.beer.name, 'Baumgartner Märzen');
    // Und der nachgetragene Code gehört auch den anderen.
    expect(online.aufrufe.any((a) => a.startsWith('upsertBeerBarcode:')), isTrue);
    await abbauen(tester);
  });

  testWidgets('Der Server ergänzt, was lokal fehlt', (tester) async {
    online.serverBiere = const [
      RemoteBeer(
        name: 'Baumgartner Zwickl',
        style: 'Zwickl',
        breweryName: 'Brauerei Baumgartner',
      ),
    ];
    await oeffnen(tester);

    await tippen(tester, 'Baumg');

    expect(find.text('Baumgartner Zwickl'), findsOneWidget,
        reason: 'Was ein anderer Nutzer angelegt hat, steht nur am Server.');
    await abbauen(tester);
  });

  testWidgets('Was lokal schon dasteht, kommt nicht doppelt', (tester) async {
    online.serverBiere = const [
      RemoteBeer(name: 'Baumgartner Pils', style: 'Pils'),
    ];
    await oeffnen(tester);

    await tippen(tester, 'Baumg');

    expect(find.text('Baumgartner Pils'), findsOneWidget,
        reason: 'Derselbe Name aus zwei Quellen ist ein Eintrag, nicht zwei.');
    await abbauen(tester);
  });

  testWidgets('Ohne Verbindung bleiben die lokalen Vorschläge',
      (tester) async {
    online.schlaegtFehl = true;
    await oeffnen(tester);

    await tippen(tester, 'Baumg');

    // Vorschläge sind ein Zusatz, kein Bestandteil des Eintragens. Wer
    // offline ein Bier anlegt, darf davon nichts merken.
    expect(find.text('Baumgartner Märzen'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Ohne EAN führt der Vorschlag zum vorhandenen Bier — und '
      'lässt kein „Speichern" stehen', (tester) async {
    await oeffnen(tester);

    await tippen(tester, 'Baumg');
    await tester.tap(find.text('Baumgartner Pils'));
    await tester.pumpAndSettle();

    // Die Falle, die hier zugeschnappt wäre: Vorher füllte die Übernahme
    // nur die Felder und liess „Speichern" scharf. Ein Druck darauf legte
    // dasselbe Bier ein zweites Mal an — lokal UND am Server. Genau das
    // Duplikat, das diese Auswahl verhindern soll.
    // Nicht auf den „Speichern"-Knopf pruefen: Der steht weit unten in
    // einer ListView und wird gar nicht erst gebaut — die Pruefung waere
    // auch beim alten, fehlerhaften Verhalten gruen gewesen. Stattdessen
    // auf den Bildschirm selbst.
    expect(find.byType(AddBeerScreen), findsNothing,
        reason: 'Das Anlegen-Formular darf hier nicht offen bleiben.');
    expect(find.textContaining('gibt es schon'), findsOneWidget);
    expect(find.textContaining('Bierseite b-pils'), findsOneWidget,
        reason: 'Wer ein vorhandenes Bier antippt, will genau dorthin.');

    final alle = await db.select(db.beers).get();
    expect(alle.length, 2);
    expect(online.aufrufe.where((a) => a.startsWith('submitCommunityBeer')),
        isEmpty);
    await abbauen(tester);
  });
}
