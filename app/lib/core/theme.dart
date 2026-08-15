import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// „Abend in der Bar": warme Bernstein/Kupfer-Palette,
/// identisch auf Android, iOS und Windows (siehe docs/05-ui-screens.md).
class BrewTheme {
  static const amber = Color(0xFFE8A33D);
  static const copper = Color(0xFFB4632C);
  static const stout = Color(0xFF1C140F);
  static const foam = Color(0xFFFAF3E7);

  static ThemeData get dark => _base(
        ColorScheme.fromSeed(
          seedColor: amber,
          brightness: Brightness.dark,
          surface: stout,
        ),
      );

  static ThemeData get light => _base(
        ColorScheme.fromSeed(
          seedColor: copper,
          brightness: Brightness.light,
          surface: foam,
        ),
      );

  static ThemeData _base(ColorScheme scheme) => ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        // Gebündeltes Roboto (pubspec fonts:) — die Web-App bleibt damit
        // auch ohne Zugriff auf fonts.gstatic.com lesbar; Emojis/Symbole
        // kommen aus den gebündelten Noto-Fallbacks statt vom Google-CDN.
        fontFamily: 'Roboto',
        // Emoji-Fallback ist plattformabhängig — und das ist keine
        // Feinheit, sondern der Unterschied zwischen einem farbigen 🍺
        // und einem schwarz-weißen Umriss.
        //
        // **Web** hat keine eigene Emoji-Schrift, auf die man sich
        // verlassen könnte. `NotoColorEmoji` wird dort zur Laufzeit
        // nachgeladen (core/emoji_font.dart); bis dahin und im
        // Fehlerfall trägt das gebündelte monochrome `NotoEmoji`.
        //
        // **Android und iOS bringen farbige Emojis mit.** Die Kette wird
        // aber VOR der Systemschrift durchsucht — stand das monochrome
        // Bundle hier unbedingt drin, gewann es gegen die farbige
        // Systemschrift, und die App zeigte blasse Umrisse, wo die
        // Web-App bunte Symbole hatte. Genau so war es bis 2026-08-15.
        //
        // `NotoSansSymbols2` bleibt überall: Es enthält keine Emojis,
        // sondern Zeichen wie ● und ○, für die es sonst keinen Ersatz
        // gibt.
        fontFamilyFallback: const [
          if (kIsWeb) ...['NotoColorEmoji', 'NotoEmoji'],
          'NotoSansSymbols2',
        ],
        cardTheme: const CardTheme(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      );
}
