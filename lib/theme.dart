import 'package:flutter/material.dart';

/// VINEROX brand colors — pulled from the Streamlit terminal tier palette.
class VineroxTheme {
  static const Color bg = Color(0xFF0A0E16);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceAlt = Color(0xFF1F2937);
  static const Color text = Color(0xFFE5E7EB);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color accent = Color(0xFF00D4AA); // BESTSTOCK
  static const Color gold = Color(0xFFFFB300);
  static const Color silver = Color(0xFFB0B0B0);
  static const Color watch = Color(0xFF60A5FA);
  static const Color bull = Color(0xFF22C55E);
  static const Color bear = Color(0xFFEF4444);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: surface,
        secondary: gold,
        onPrimary: Colors.black,
        onSurface: text,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
            color: text, fontSize: 22, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(
            color: text, fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: text, fontSize: 14),
        bodySmall: TextStyle(color: textMuted, fontSize: 12),
      ),
    );
  }

  static Color tierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'BESTSTOCK':
        return accent;
      case 'GOLD':
        return gold;
      case 'SILVER':
        return silver;
      case 'WATCH':
        return watch;
      default:
        return accent;
    }
  }
}
