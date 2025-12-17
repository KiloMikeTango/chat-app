// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  // Remove the old getter:
  // bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Add this helper instead:
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

// Light theme – chat bubble blue (not too bright)
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1777F2),
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F5F8),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
  ),
  // This is what you can use for BOTH incoming/outgoing chat cards in light mode
  cardColor: const Color.fromARGB(
    255,
    209,
    232,
    255,
  ), // medium blue, not too bright
  iconTheme: const IconThemeData(size: 22, color: Colors.black87),
  textTheme: const TextTheme().apply(
    fontFamily: 'Inter',
    bodyColor: Colors.black87,
    displayColor: Colors.black87,
  ),
);

// Dark theme – same color 0xFF111111 for ALL cards
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1777F2),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF050505),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    backgroundColor: Color(0xFF050505),
    foregroundColor: Colors.white,
  ),
  // This will be your shared chat card color in dark mode
  cardColor: const Color(0xFF111111),
  iconTheme: const IconThemeData(size: 22, color: Colors.white70),
  textTheme: const TextTheme().apply(
    fontFamily: 'Inter',
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
);
