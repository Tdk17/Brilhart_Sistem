import 'package:flutter/material.dart';

abstract final class AppColors {
  static const black = Color(0xFF070707);
  static const surface = Color(0xFF111111);
  static const surfaceAlt = Color(0xFF191919);
  static const silver = Color(0xFFC8C8C8);
  static const silverDark = Color(0xFF8D8D8D);
  static const gold = Color(0xFFD4AF37);
  static const goldSoft = Color(0xFFF0D87A);
  static const white = Color(0xFFF5F5F5);
  static const danger = Color(0xFFD9534F);
  static const success = Color(0xFF3FAE76);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
      primary: AppColors.gold,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: scheme,
      fontFamily: 'Arial',
      dividerColor: Colors.white12,
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: Colors.white10),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }
}
