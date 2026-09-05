import 'package:flutter/services.dart';

/// Ohne Browser: in die Zwischenablage. Gibt zurück, ob eine Datei
/// entstanden ist — hier also `false`, damit die Oberfläche das Richtige
/// sagen kann.
Future<bool> tabelleAusgeben(String inhalt, String dateiname) async {
  await Clipboard.setData(ClipboardData(text: inhalt));
  return false;
}
