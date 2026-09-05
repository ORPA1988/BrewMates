import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Im Browser: ein Blob und ein Klick auf einen unsichtbaren Link — der
/// übliche Weg, weil es keine Datei-API gibt, die ohne Nutzergeste
/// speichern darf.
///
/// Der Aufruf **muss** aus einer Nutzeraktion heraus kommen, sonst
/// blockiert der Browser den Download stillschweigend. Das ist hier
/// gegeben: Es hängt an einem Knopf.
Future<bool> tabelleAusgeben(String inhalt, String dateiname) async {
  // `text/csv` statt `application/octet-stream`, damit der Browser den
  // Namen nicht überschreibt; `charset=utf-8` zusammen mit der BOM im
  // Text, damit Excel die Umlaute nimmt.
  final blob = web.Blob(
    [inhalt.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anker = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = dateiname;
  web.document.body!.appendChild(anker);
  anker.click();
  anker.remove();
  // Der Blob bleibt sonst im Speicher, bis der Tab zugeht.
  web.URL.revokeObjectURL(url);
  return true;
}
