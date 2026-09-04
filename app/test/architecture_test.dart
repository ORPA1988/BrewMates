// Wächter über Dateien im Repo: liest sie mit `dart:io`. Ein Browser
// hat kein Dateisystem, und geprüft wird hier ohnehin das Repo und
// nicht die App. Siehe docs/features/18-plattformen.md.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter über die Schichtregeln aus `.claude/architecture.md`.
///
/// Anlass: `domain/statistics.dart` importierte `data/db/database.dart`
/// und durchbrach damit als erste Datei eine Regel, welche die
/// Projektdoku als lückenlos beschrieb. Aufgefallen ist das erst bei
/// einem Review — also Monate später als nötig. Eine Regel, die nur in
/// einem Dokument steht, wird irgendwann gebrochen; diese hier bricht ab
/// jetzt den Testlauf.
///
/// Bewusst als Textprüfung über die Quelldateien und nicht über ein
/// Analyse-Plugin: Zwanzig Zeilen, die jeder versteht und die keine
/// zusätzliche Abhängigkeit kosten.
void main() {
  /// Alle Dart-Dateien unter [dir], ohne generierte.
  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  /// Die Ziele aller `import`-Zeilen von [f].
  Iterable<String> importsOf(File f) => f
      .readAsLinesSync()
      .where((l) => l.trimLeft().startsWith('import '))
      .map((l) {
        final m = RegExp(r"""import\s+['"]([^'"]+)['"]""").firstMatch(l);
        return m?.group(1) ?? '';
      })
      .where((s) => s.isNotEmpty);

  /// Altlasten, die die Regel noch brechen.
  ///
  /// Diese Liste ist eine Ratsche: Sie darf schrumpfen, nie wachsen. Wer
  /// hier etwas einträgt, statt aufzuräumen, verschiebt das Problem.
  ///
  /// **Seit 2026-08-15 leer** (Backlog A-7 erledigt): `badges` und
  /// `challenges` importierten die Datenbank nicht nur, sie fragten sie ab.
  /// Das Laden liegt jetzt in `data/badge_engine.dart` bzw.
  /// `data/challenge_engine.dart`, die Bewertung im Domain.
  const bekannteAltlasten = <String>{};

  test('domain/ importiert nichts aus data/ oder features/', () {
    final verstoesse = <String>[];
    for (final f in dartFiles('lib/domain')) {
      final pfad = f.path.replaceAll(r'\', '/');
      if (bekannteAltlasten.contains(pfad)) continue;
      for (final i in importsOf(f)) {
        if (i.contains('data/') || i.contains('features/')) {
          verstoesse.add('$pfad → $i');
        }
      }
    }
    expect(
      verstoesse,
      isEmpty,
      reason: 'domain/ ist reine Logik. Was aus data/ gebraucht wird, '
          'gehört als eigener Typ nach domain/ (siehe StatsEntry) oder '
          'als Wert-Enum nach core/ (siehe ServingStyle).',
    );
  });

  test('die Liste der Altlasten schrumpft nur — kein Eintrag ist veraltet',
      () {
    // Sonst bliebe eine aufgeräumte Datei für immer ausgenommen und die
    // Ratsche würde stumpf.
    for (final pfad in bekannteAltlasten) {
      final f = File(pfad);
      expect(f.existsSync(), isTrue, reason: '$pfad gibt es nicht mehr.');
      final nochVerletzt = importsOf(f)
          .any((i) => i.contains('data/') || i.contains('features/'));
      expect(
        nochVerletzt,
        isTrue,
        reason: '$pfad ist aufgeräumt — aus bekannteAltlasten streichen.',
      );
    }
  });

  test('domain/ importiert kein Flutter', () {
    final verstoesse = <String>[];
    for (final f in dartFiles('lib/domain')) {
      for (final i in importsOf(f)) {
        if (i.startsWith('package:flutter')) verstoesse.add('${f.path} → $i');
      }
    }
    expect(verstoesse, isEmpty,
        reason: 'domain/ muss ohne Widget-Baum testbar bleiben.');
  });

  test('kein features/-Ordner importiert einen anderen', () {
    final verstoesse = <String>[];
    for (final f in dartFiles('lib/features')) {
      // Der eigene Ordner ist der zweitletzte Pfadbestandteil.
      final teile = f.path.replaceAll(r'\', '/').split('/');
      final eigener = teile[teile.indexOf('features') + 1];
      for (final i in importsOf(f)) {
        // Zwei Schreibweisen — und die zweite hat diese Prüfung lange
        // umgangen: `package:…/features/x/…` nennt den Ordner im Pfad,
        // `../x/…` nicht. Zwei echte Verstöße (map → venues, scan →
        // beers) steckten deshalb unbemerkt im Code, während der Test
        // grün leuchtete. Ein Wächter mit blindem Fleck ist schlimmer als
        // keiner: Er erzeugt Vertrauen, das er nicht deckt.
        final absolut = RegExp(r'features/([^/]+)/').firstMatch(i)?.group(1);
        final relativ = RegExp(r'^\.\./([^/.]+)/').firstMatch(i)?.group(1);
        final fremder = absolut ?? relativ;
        if (fremder != null && fremder != eigener) {
          verstoesse.add('${f.path} → $i');
        }
      }
    }
    expect(
      verstoesse,
      isEmpty,
      reason: 'Navigation läuft über core/router.dart. Nur so bleibt jede '
          'Funktion einzeln entfernbar.',
    );
  });

  test('lib/ verwendet kein dart:io außerhalb der Plattform-Weiche', () {
    final verstoesse = <String>[];
    for (final f in dartFiles('lib')) {
      final pfad = f.path.replaceAll(r'\', '/');
      // `data/db/connection/` ist genau der Ort, an dem dart:io stehen
      // DARF: Der native Pfad wird per Conditional Import gewählt und
      // landet nie im Web-Bündel. Das ist die Ausnahme, die die Regel
      // erst durchsetzbar macht.
      if (pfad.contains('data/db/connection/')) continue;
      for (final i in importsOf(f)) {
        if (i == 'dart:io') verstoesse.add(pfad);
      }
    }
    expect(
      verstoesse,
      isEmpty,
      reason: 'Plattform-Weichen laufen über kIsWeb bzw. Conditional '
          'Imports (data/db/connection/). Die CI erzwingt flutter build web.',
    );
  });
}
