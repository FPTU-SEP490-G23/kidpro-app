import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // KidPro Brand Colors
  static const primary = Color(0xFF275A4E);       // Forest Green
  static const primaryDark = Color(0xFF1E4D40);   // Deep Green
  static const accent = Color(0xFFE5A93C);        // Warm Gold
  static const highlight = Color(0xFF78C2AD);     // Mint Green

  // Status
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF2563EB);

  // Attendance
  static const present = Color(0xFF10B981);
  static const notArrived = Color(0xFFF59E0B);
  static const onLeave = Color(0xFF94A3B8);

  // Alert
  static const strangerAlert = Color(0xFFDC2626);

  // Background
  static const scaffoldLight = Color(0xFFF4F7F5);
  static const scaffoldDark = Color(0xFF0F172A);
  static const cardDark = Color(0xFF1E293B);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.scaffoldLight,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.scaffoldDark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      );
}
