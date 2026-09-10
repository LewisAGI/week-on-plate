import 'package:flutter/material.dart';

const Color kWhite = Color(0xFFFFFFFF);
const Color kGreen = Color(0xFF1F7A4D);
const Color kGreenDark = Color(0xFF0F3D28);
const Color kGreenSoft = Color(0xFFF3F8F5);
const Color kInk = Color(0xFF12261C);
const Color kMuted = Color(0xFF5B6B62);

ThemeData weekOnPlateTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: kGreen,
    brightness: Brightness.light,
    surface: kWhite,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: base.copyWith(
      primary: kGreen,
      onPrimary: kWhite,
      surface: kWhite,
      onSurface: kInk,
    ),
    scaffoldBackgroundColor: kWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: kWhite,
      foregroundColor: kGreen,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: kGreen,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kGreen,
      foregroundColor: kWhite,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kGreenSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kGreenSoft,
      selectedColor: kGreen,
      labelStyle: const TextStyle(color: kInk),
      secondaryLabelStyle: const TextStyle(color: kWhite),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cardTheme: CardThemeData(
      color: kWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE3EDE7)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: kWhite,
      indicatorColor: kGreenSoft,
    ),
  );
}
