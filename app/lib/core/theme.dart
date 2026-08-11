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
