import 'package:flutter/material.dart';

/// Material 3 themes. The app follows the system light/dark setting.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF4F6BED);
  static const String fontFamily = 'Manrope';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.standard,
      cardTheme: const CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
}
