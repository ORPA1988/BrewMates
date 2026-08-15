import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/community_sync.dart';
import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/features/map/map_screen.dart';

/// Die Karte ist der Bildschirm, an dem das Privatsphäre-Versprechen
/// sichtbar wird: Wer nicht befreundet ist, erscheint **nur als Zahl**.
///
/// Backlog B-5. Ich hatte zunächst behauptet, `flutter_map` sei im
/// Widget-Test nicht lauffähig. Das stimmt so nicht: Die Karte baut sich
/// auf, sie scheitert nur an den Kacheln — im Test gibt es kein Netz,
/// jede Anfrage schlägt fehl, und `flutter_map` versucht es endlos
/// weiter. Mit einem Kachel-Anbieter, der nichts lädt, ist der Bildschirm
/// ganz normal prüfbar. Was wirklich ein Gerät braucht, ist der Scanner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await CommunitySync(db).importBundledData();
  });

  Future<void> zeige(WidgetTester tester, {int andereAktiv = 0}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onlineServiceProvider.overrideWith((ref) async => null),
        otherActiveCountProvider.overrideWith((ref) async => andereAktiv),
        mapTileProviderProvider.overrideWithValue(_LeereKacheln()),
      ],
      child: const MaterialApp(home: MapScreen()),
    ));
    // Kein pumpAndSettle: Die Karte hält Animationen dauerhaft am Laufen.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Baut den Baum ab und lässt Drift seine Stream-Timer aufräumen —
  /// sonst meldet der Test „Pending timers" statt eines Ergebnisses.
  Future<void> abbauen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }

  testWidgets('Die Karte baut sich auf', (tester) async {
    await zeige(tester);
    expect(find.byType(MapScreen), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Andere BrewMates erscheinen als Zahl, nicht als Ort',
      (tester) async {
    await zeige(tester, andereAktiv: 3);

    expect(find.text(activeUsersLabel(3)), findsOneWidget);
    // Der Zähler ist die EINZIGE Spur von Nicht-Freunden auf der Karte.
    // Fände sich hier ein Name oder ein Ort, wäre das Versprechen aus
    // docs/06-karte.md gebrochen.
    expect(find.textContaining('weitere BrewMates aktiv'), findsOneWidget);
    await abbauen(tester);
  });

  testWidgets('Ohne andere Aktive fehlt der Zähler ganz', (tester) async {
    await zeige(tester, andereAktiv: 0);
    // „0 weitere aktiv" wäre eine Aussage über Abwesenheit — und die ist
    // ebenfalls eine Information über andere Menschen.
    expect(find.textContaining('weitere BrewMates aktiv'), findsNothing);
    await abbauen(tester);
  });
}

/// Kachel-Anbieter, der nichts lädt.
///
/// Ohne ihn feuert die Karte Dutzende Netzanfragen ab, die im Test alle
/// mit 400 zurückkommen — jede davon ein Fehler, der den Lauf zum
/// Scheitern bringt, plus endlose Wiederholungen.
class _LeereKacheln extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentesPng);
}

/// Ein 1×1-Pixel-PNG, vollständig transparent.
final _transparentesPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
