import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/location_service.dart';
import 'package:brewmates/data/providers.dart';
import 'package:brewmates/main.dart';

/// Ob die App für Menschen taugt, die schlecht sehen oder zittrige
/// Finger haben — gemessen, nicht gehofft.
///
/// Flutter bringt drei Prüfungen mit, die genau das beantworten. Sie
/// laufen gegen den **fertig gebauten Bildschirm**, nicht gegen einzelne
/// Widgets: Was zählt, ist die Farbe, die am Ende auf dem Glas landet,
/// und die entsteht erst aus dem Theme.
///
/// * `androidTapTargetGuideline` — jedes Ziel mindestens 48×48. Der
///   Klassiker sind `IconButton`s mit gesetzter `iconSize`: das Symbol
///   wird kleiner, die Trefferfläche schrumpft mit.
/// * `labeledTapTargetGuideline` — kein Knopf ohne Beschriftung. Ein
///   nacktes Symbol liest TalkBack als „Schaltfläche", sonst nichts.
/// * `textContrastGuideline` — 4,5:1 zwischen Text und Untergrund
///   (WCAG AA), bei großem Text 3:1.
///
/// **Beide Helligkeiten**, weil es zwei verschiedene Paletten sind:
/// `BrewTheme.light` keimt aus Kupfer, `BrewTheme.dark` aus Bernstein.
/// Ein Kontrast, der hell trägt, kann dunkel durchfallen.
///
/// **Warum das keine Formalie ist:** BrewMates wird abends in Lokalen
/// benutzt, einhändig, oft mit dem Glas in der anderen Hand. Genau die
/// Lage, in der 44 Pixel zu wenig sind.
///
/// Die Karte fehlt bewusst: `flutter_map` holt Kacheln aus dem Netz und
/// braucht dafür einen eigenen Stub (siehe `map_screen_test.dart`). Ihre
/// Bedienelemente sind dieselben Material-Bausteine wie überall sonst.
class _FakeLocationService extends LocationService {
  const _FakeLocationService();

  @override
  Future<LocationResult> getCurrentPosition() async =>
      const LocationGranted(48.2082, 16.3738);
}

Widget _app() => ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.memory();
          ref.onDispose(db.close);
          return db;
        }),
        locationServiceProvider
            .overrideWithValue(const _FakeLocationService()),
        // Kein Supabase in Widget-Tests: der Offline-Pfad ist der Testpfad.
        onlineServiceProvider.overrideWith((ref) async => null),
      ],
      child: const BrewMatesApp(),
    );

/// Baut den Baum ab und lässt ausstehende Zero-Duration-Timer
/// (Drift-Streams, DB-Close) auslaufen, bevor flutter_test seine
/// Timer-Invariante prüft.
Future<void> _windDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Zählt die antippbaren Knoten im Semantik-Baum — also genau die
/// Menge, über die `androidTapTargetGuideline` urteilt.
int _tapZiele(WidgetTester tester) {
  var gezaehlt = 0;
  void geh(SemanticsNode knoten) {
    if (knoten.getSemanticsData().hasAction(SemanticsAction.tap)) {
      gezaehlt++;
    }
    knoten.visitChildren((kind) {
      geh(kind);
      return true;
    });
  }

  geh(tester.getSemantics(find.byType(MaterialApp)));
  return gezaehlt;
}

void main() {
  /// Fährt einen Tab in einer Helligkeit gegen alle drei Prüfungen.
  Future<void> pruefe(
    WidgetTester tester, {
    required String tab,
    required Brightness helligkeit,
  }) async {
    // **Telefonformat, nicht die Standard-Testgröße.** Bei 800×600 lag
    // die Navigationsleiste außerhalb des Ausschnitts und stand deshalb
    // gar nicht im Semantik-Baum: Der Test war grün, ohne das zentrale
    // Bedienelement der App je angesehen zu haben (3 Tap-Ziele statt 8).
    // Ein Wächter mit blindem Fleck ist schlimmer als keiner.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.platformDispatcher.platformBrightnessTestValue = helligkeit;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final semantik = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // „Home" ist schon offen; die anderen Tabs liegen in der Leiste.
    if (tab != 'Home') {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }

    // Zwei Zusicherungen, damit dieser Test nicht still zum Papiertiger
    // werden kann. Ohne sie wäre er auch dann grün, wenn die Helligkeit
    // nicht durchschlägt (vier der acht Fälle wären Dubletten) oder der
    // Bildschirm leer bliebe (nichts zu prüfen ist nicht dasselbe wie
    // nichts zu beanstanden).
    final kontext = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(kontext).brightness, helligkeit,
        reason: 'Die Helligkeit schlägt nicht bis ins Theme durch');
    expect(_tapZiele(tester), greaterThan(5),
        reason: 'Weniger Tap-Ziele als die fünf Tabs der Leiste — '
            'da wurde etwas nicht gebaut');

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    semantik.dispose();
    await _windDown(tester);
  }

  for (final helligkeit in [Brightness.light, Brightness.dark]) {
    final name = helligkeit == Brightness.light ? 'hell' : 'dunkel';

    for (final tab in ['Home', 'Feed', 'Entdecken', 'Profil']) {
      testWidgets('$tab ist bedienbar und lesbar ($name)', (tester) async {
        await pruefe(tester, tab: tab, helligkeit: helligkeit);
      });
    }
  }
}
