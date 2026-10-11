import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF6366F1);     // Indigo 500
  static const primaryDark = Color(0xFF4F46E5);  // Indigo 600
  static const accent = Color(0xFF818CF8);        // Indigo 400

  // Status
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Attendance
  static const present = Color(0xFF10B981);
  static const notArrived = Color(0xFFF59E0B);
  static const onLeave = Color(0xFF94A3B8);

  // Alert
  static const strangerAlert = Color(0xFFDC2626);

  // Background
  static const scaffoldLight = Color(0xFFF8FAFC);
  static const scaffoldDark = Color(0xFF0B0F19);
  static const cardDark = Color(0xFF111827);
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
