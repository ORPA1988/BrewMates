import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Im Browser: ein Blob und ein Klick auf einen unsichtbaren Link.
///
/// Der Aufruf **muss** aus einer Nutzeraktion heraus kommen, sonst
/// blockiert der Browser den Download stillschweigend — hier hängt er an
/// einem Knopf.
Future<bool> bildAusgeben(Uint8List bytes, String dateiname) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final anker = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = dateiname;
  web.document.body!.appendChild(anker);
  anker.click();
  anker.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
