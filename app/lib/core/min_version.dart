/// „Update erforderlich" — der Riegel für Versionen, die der Server nicht
/// mehr bedienen kann.
///
/// **Warum es das gibt:** Ohne Riegel muss jede Migration ewig
/// rücksichtsvoll bleiben. Ein entzogenes Recht oder eine entfernte Spalte
/// bricht ältere Clients in unerklärliche Fehler — der Nutzer sieht eine
/// leere Freundesliste und weiß nicht, dass seine App zu alt ist. Deshalb
/// liegt Migration 0026 auf Halde und `beers.barcode` bleibt in 0028
/// stehen, obwohl sie ersetzt ist.
///
/// Mit Riegel wird daraus eine klare Ansage, und die Migration darf
/// entziehen.
///
/// **Die eine Regel, die zählt:** Ein Netzproblem darf niemals aussperren.
/// BrewMates funktioniert ohne Konto und ohne Verbindung vollständig —
/// wer im Funkloch sitzt, muss einchecken können. Gesperrt wird nur bei
/// einer klaren, verstandenen Antwort des Servers.
library;

import 'app_update.dart' show compareAppVersions;

/// Entscheidet, ob die laufende App zu alt ist.
///
/// [minVersion] ist die Antwort des Servers; `null` heißt „nicht
/// erreichbar oder nicht gesetzt" und führt **nie** zur Sperre.
bool istUpdatePflicht({
  required String appVersion,
  required String? minVersion,
}) {
  if (minVersion == null) return false;
  final min = minVersion.trim();
  if (min.isEmpty) return false;
  // Unlesbare Antwort wie eine fehlende behandeln: Lieber jemanden zu
  // viel hereinlassen als alle aussperren, weil ein Tippfehler in einer
  // Konfigurationszeile steht.
  if (!RegExp(r'^v?\d+(\.\d+)*').hasMatch(min)) return false;
  return compareAppVersions(appVersion, min) < 0;
}
