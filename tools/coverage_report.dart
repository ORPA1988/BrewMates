// Liest `app/coverage/lcov.info` und meldet die Zeilenabdeckung.
//
// Warum ein eigenes Skript und kein fertiges Werkzeug: Es soll ohne
// zusätzliche Abhängigkeit in der CI laufen, und es soll **generierten
// Code ausschließen**. `database.g.dart` allein ist gut ein Drittel der
// gemessenen Zeilen; ihn mitzuzählen macht die Zahl kleiner, ohne dass
// sie etwas über die Tests aussagt — und niemand schreibt Tests für
// generierten Code.
//
// Aufruf (aus dem Wurzelverzeichnis):
//   dart tools/coverage_report.dart [--min <prozent>]
//
// `--min` lässt den Lauf scheitern, wenn die Abdeckung darunter liegt.
// Der Wert ist eine **Ratsche**: Er darf steigen, nie sinken. Er steht in
// `.github/workflows/ci.yml` und nicht hier, damit die Änderung im Diff
// des PRs auffällt, der sie verursacht.

import 'dart:io';

void main(List<String> args) {
  // Funktioniert aus dem Wurzelverzeichnis wie aus `app/` heraus — die CI
  // ruft aus `app/` auf, von Hand ruft man meist oben auf.
  final kandidaten = ['app/coverage/lcov.info', 'coverage/lcov.info'];
  final datei = kandidaten.map(File.new).firstWhere(
        (f) => f.existsSync(),
        orElse: () => File(kandidaten.first),
      );
  if (!datei.existsSync()) {
    stderr.writeln('Keine lcov.info gefunden (gesucht: '
        '${kandidaten.join(", ")}) — erst `flutter test --coverage` '
        'laufen lassen.');
    exit(2);
  }

  var min = 0.0;
  final i = args.indexOf('--min');
  if (i >= 0 && i + 1 < args.length) min = double.parse(args[i + 1]);

  final dateien = <String, ({int zeilen, int getroffen})>{};
  String? aktuell;
  var lf = 0;
  for (final zeile in datei.readAsLinesSync()) {
    if (zeile.startsWith('SF:')) {
      aktuell = zeile.substring(3).replaceAll(r'\', '/');
      lf = 0;
    } else if (zeile.startsWith('LF:')) {
      lf = int.parse(zeile.substring(3));
    } else if (zeile.startsWith('LH:') && aktuell != null) {
      dateien[aktuell] =
          (zeilen: lf, getroffen: int.parse(zeile.substring(3)));
    }
  }

  bool gezaehlt(String pfad) => !pfad.endsWith('.g.dart');

  var zeilen = 0;
  var getroffen = 0;
  dateien.forEach((pfad, wert) {
    if (!gezaehlt(pfad)) return;
    zeilen += wert.zeilen;
    getroffen += wert.getroffen;
  });
  final prozent = zeilen == 0 ? 0.0 : 100 * getroffen / zeilen;

  // Die zehn schwächsten Stellen, die groß genug sind, um zu zählen —
  // damit die Zahl nicht nur ein Wert ist, sondern eine Richtung.
  final schwach = dateien.entries
      .where((e) => gezaehlt(e.key) && e.value.zeilen > 150)
      .map((e) => (
            pfad: e.key.split('lib/').last,
            zeilen: e.value.zeilen,
            anteil: 100 * e.value.getroffen / e.value.zeilen,
          ))
      .toList()
    ..sort((a, b) => a.anteil.compareTo(b.anteil));

  final puffer = StringBuffer()
    ..writeln('## Testabdeckung: '
        '**${prozent.toStringAsFixed(1)} %** '
        '($getroffen von $zeilen Zeilen, ohne generierten Code)')
    ..writeln()
    ..writeln('| Abdeckung | Zeilen | Datei |')
    ..writeln('|---:|---:|---|');
  for (final e in schwach.take(10)) {
    puffer.writeln('| ${e.anteil.toStringAsFixed(1)} % '
        '| ${e.zeilen} | `${e.pfad}` |');
  }

  stdout.writeln(puffer);

  // In der CI zusätzlich in die Job-Zusammenfassung, damit der Wert im PR
  // sichtbar ist, ohne die Logs zu öffnen.
  final zusammenfassung = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (zusammenfassung != null) {
    File(zusammenfassung).writeAsStringSync(puffer.toString(),
        mode: FileMode.append);
  }

  if (prozent + 0.05 < min) {
    stderr.writeln('Abdeckung ${prozent.toStringAsFixed(1)} % liegt unter '
        'der Untergrenze ${min.toStringAsFixed(1)} %. Die Grenze steht in '
        '.github/workflows/ci.yml und darf nur steigen.');
    exit(1);
  }
}
