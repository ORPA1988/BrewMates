import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:http/http.dart' as http;

/// 🎨 Farbige Emojis für die Web-App: `web/fonts/NotoColorEmoji.ttf`
/// (~10,7 MB, CBDT) liegt NUR im Web-Deployment — nicht in den
/// App-Assets, damit das Android-APK schlank bleibt (Android rendert
/// Emojis ohnehin nativ in Farbe). Der Font wird nach dem App-Start
/// asynchron geladen; bis dahin (und falls der Download scheitert)
/// greifen die gebündelten monochromen Noto-Fallbacks. FontLoader.load()
/// stößt das Re-Rendering aller Texte automatisch an; der
/// Service-Worker cached die Datei nach dem ersten Besuch.
Future<void> loadColorEmojiFont() async {
  if (!kIsWeb) return;
  try {
    // Relativ zur Seiten-URL (base href /BrewMates/ inklusive).
    final response = await http.get(Uri.parse('fonts/NotoColorEmoji.ttf'));
    if (response.statusCode != 200) return;
    final loader = FontLoader('NotoColorEmoji')
      ..addFont(Future.value(ByteData.sublistView(response.bodyBytes)));
    await loader.load();
  } catch (_) {
    // Kein Farb-Font verfügbar → monochrome Emojis bleiben lesbar.
  }
}
