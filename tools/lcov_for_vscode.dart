// Schreibt `app/coverage/lcov.vscode.info` — dieselbe Abdeckung wie
// `lcov.info`, aber mit Pfaden, die VS Code vom Wurzelverzeichnis aus
// findet.
//
// Warum überhaupt: `flutter test --coverage` läuft in `app/` und schreibt
// die Quelldateien deshalb als `lib\core\theme.dart`. Der geöffnete
// Ordner ist aber das Repo-Wurzelverzeichnis — dort gibt es kein `lib/`.
// Coverage Gutters findet die Datei, aber keine einzige Quelle und zeigt
// nichts an. Hier werden die Pfade auf `app/lib/…` gehoben und die
// Backslashes zu Schrägstrichen gemacht.
//
// Bewusst eine **zweite** Datei statt einer Umschreibung an Ort und
// Stelle: `tools/coverage_report.dart` und die CI lesen `lcov.info`
// weiter unverändert. Ein Werkzeug für den Arbeitsplatz darf die
// Messgrundlage nicht anfassen.
//
// Aufruf (aus dem Wurzelverzeichnis oder aus `app/`):
//   dart tools/lcov_for_vscode.dart

import 'dart:io';

void main() {
  final kandidaten = ['app/coverage/lcov.info', 'coverage/lcov.info'];
  final quelle = kandidaten.map(File.new).where((f) => f.existsSync());
  if (quelle.isEmpty) {
    stderr.writeln(
      'Keine lcov.info gefunden. Erst `flutter test --coverage` in app/ '
      'laufen lassen.',
    );
    exit(1);
  }

  final datei = quelle.first;
  final zeilen = datei.readAsLinesSync().map((zeile) {
    if (!zeile.startsWith('SF:')) return zeile;
    final pfad = zeile.substring(3).replaceAll(r'\', '/');
    // Schon gehobene Pfade nicht doppelt heben.
    return pfad.startsWith('app/') ? 'SF:$pfad' : 'SF:app/$pfad';
  });

  final ziel = File('${datei.parent.path}/lcov.vscode.info');
  ziel.writeAsStringSync('${zeilen.join('\n')}\n');
  stdout.writeln('Geschrieben: ${ziel.path}');
}
