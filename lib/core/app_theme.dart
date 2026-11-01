import 'package:flutter/material.dart';

class AppTheme {
  static const forest = Color(0xFF192A24);
  static const gold = Color(0xFFD39725);
  static const paper = Color(0xFFF6F0E5);
  static const card = Color(0xFFFFFDFA);
  static const border = Color(0xFFE8D8BE);
  static const muted = Color(0xFF7D8176);
  static const green = Color(0xFF008B62);
  static const red = Color(0xFFE83D24);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: gold,
      primary: forest,
      secondary: gold,
      surface: card,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: forest,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: gold, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: forest,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: forest,
        fontSize: 29,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: forest,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      titleMedium: TextStyle(
        color: forest,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(color: forest, fontSize: 14),
      bodySmall: TextStyle(color: muted, fontSize: 12),
    ),
  );
}
