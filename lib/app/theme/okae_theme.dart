import 'package:flutter/material.dart';

const ink = Color(0xFF202B29);
const orange = Color(0xFFB94721);
const paper = Color(0xFFF7F5EF);
ThemeData okaeTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: orange,
    primary: orange,
    surface: paper,
    onSurface: ink,
  ),
  textTheme: const TextTheme(
    displayMedium: TextStyle(
      fontSize: 52,
      height: 1.05,
      fontWeight: FontWeight.w800,
      letterSpacing: -2,
      color: ink,
    ),
    headlineLarge: TextStyle(
      fontSize: 36,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      color: ink,
    ),
    titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
    bodyLarge: TextStyle(fontSize: 17, height: 1.5, color: ink),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    centerTitle: false,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
  ),
);
