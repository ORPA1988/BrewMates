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
        // Knöpfe und Chips waren bis 0.10.27 reine Material-3-Vorgabe: 40 px
        // hoch, Normalschrift, 20 px Radius. Das ist ordentlich und
        // austauschbar. Festgelegt sind jetzt Höhe, Radius und Schriftschnitt
        // — die Farben bleiben bewusst die des `ColorScheme`, weil Material
        // deren Kontrast bereits sicherstellt und ein selbst gewählter Ton
        // ihn brechen könnte (siehe docs/14).
        filledButtonTheme: FilledButtonThemeData(style: _buttonStyle),
        elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: _buttonStyle.copyWith(
            side: WidgetStatePropertyAll(
              BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        // Material legt unter jeden Chip eine unsichtbare 48er-Trefferfläche.
        // Die *sichtbare* Höhe kommt aus dem Innenabstand — einhändig, mit dem
        // Glas in der anderen Hand, ist der Unterschied spürbar.
        //
        // **Die Farbe muss mit.** Ein `labelStyle` ohne `color` ersetzt den
        // Stil, den Material aus dem Schema ableitet, vollständig — die
        // Schrift fiel dadurch auf einen Containerton zurück und stand mit
        // 1,1:1 weiß auf weiß. `barrierefreiheit_test` hat das im ersten
        // Lauf gefangen; ohne ihn wäre es in ein Release gegangen.
        chipTheme: ChipThemeData(
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
          secondaryLabelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSecondaryContainer,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        ),
      );

  static final ButtonStyle _buttonStyle = FilledButton.styleFrom(
    minimumSize: const Size(64, 48),
    padding: const EdgeInsets.symmetric(horizontal: 22),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
  );

  /// Verlauf für die Hero-Flächen. Er läuft **immer in Richtung des
  /// Untergrunds**: hell wird heller, dunkel wird dunkler. Damit kann er den
  /// Kontrast zur Schrift nie verschlechtern, sondern nur verbessern — ein
  /// Verlauf, der in die Gegenrichtung liefe, würde `barrierefreiheit_test`
  /// in genau einer der beiden Paletten brechen.
  static LinearGradient lebhaft(ColorScheme scheme, Color grund) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(grund, scheme.surface, 0.22)!,
          grund,
        ],
      );
}
