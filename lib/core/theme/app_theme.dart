import 'package:flutter/material.dart';

class AppColors {
  static const green = Color(0xFF145C45);
  static const greenDark = Color(0xFF0D3F32);
  static const ivory = Color(0xFFF8F6EF);
  static const gold = Color(0xFFC5A45D);
  static const ink = Color(0xFF202923);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.ivory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.light,
          surface: AppColors.ivory,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.ivory,
          foregroundColor: AppColors.ink,
          centerTitle: false,
          elevation: 0,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101A16),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      );
}
