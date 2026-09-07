import 'package:flutter/material.dart';

/// Stock Arena design system, recovered from the production web build.
class AC {
  static const bg = Color(0xFF080D15);
  static const bgAlt = Color(0xFF0D1420);
  static const surface = Color(0xFF131C2B);
  static const surfaceHi = Color(0xFF1B2637);
  static const stroke = Color(0xFF243146);

  static const text = Color(0xFFE8EDF5);
  static const textDim = Color(0xFF93A1B8);
  static const textFaint = Color(0xFF5D6B84);

  static const gold = Color(0xFFF5B940);
  static const goldDeep = Color(0xFFC98A17);
  static const teal = Color(0xFF2FD3A6);
  static const blue = Color(0xFF4B9BFF);
  static const purple = Color(0xFF9A7BFF);

  static const bull = Color(0xFF29C56F);
  static const bear = Color(0xFFF2565A);
  static const warn = Color(0xFFFFA13B);

  static const boardColor = blue;
  static const fansColor = gold;

  static const radius = 18.0;
  static const radiusSm = 12.0;

  static BoxDecoration panel({Color? border, Gradient? gradient, Color? fill}) =>
      BoxDecoration(
        color: gradient == null ? (fill ?? surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? stroke),
      );

  /// Tier colour used across squad cards, chests and rank badges.
  static Color tier(String name) {
    switch (name.toUpperCase()) {
      case 'GOLD':
      case 'BESTSTOCK':
        return gold;
      case 'SILVER':
        return const Color(0xFFB9C3D2);
      case 'BRONZE':
        return const Color(0xFFCD7F32);
      case 'ELITE':
        return purple;
      default:
        return blue;
    }
  }
}

ThemeData buildArenaTheme() {
  const scheme = ColorScheme.dark(
    primary: AC.gold,
    onPrimary: Color(0xFF1A1206),
    secondary: AC.teal,
    surface: AC.surface,
    onSurface: AC.text,
    error: AC.bear,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AC.bg,
    fontFamily: 'Rubik',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AC.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Fredoka',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AC.text,
      ),
    ),
    dividerTheme:
        const DividerThemeData(color: AC.stroke, space: 1, thickness: 1),
    textTheme:
        base.textTheme.apply(bodyColor: AC.text, displayColor: AC.text).copyWith(
              displaySmall: const TextStyle(
                  fontFamily: 'Fredoka', fontSize: 26, fontWeight: FontWeight.w700),
              titleLarge: const TextStyle(
                  fontFamily: 'Fredoka', fontSize: 20, fontWeight: FontWeight.w600),
              titleMedium:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              bodyMedium: const TextStyle(fontSize: 14, height: 1.35),
              bodySmall: const TextStyle(
                  fontSize: 12, color: AC.textDim, height: 1.35),
              labelLarge:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AC.gold,
        foregroundColor: const Color(0xFF1A1206),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontFamily: 'Fredoka', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AC.text,
        side: const BorderSide(color: AC.stroke),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AC.bgAlt,
      hintStyle: const TextStyle(color: AC.textFaint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AC.radiusSm),
        borderSide: const BorderSide(color: AC.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AC.radiusSm),
        borderSide: const BorderSide(color: AC.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AC.radiusSm),
        borderSide: const BorderSide(color: AC.gold),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AC.surfaceHi,
      contentTextStyle: TextStyle(color: AC.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
