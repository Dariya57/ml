import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const _kThemeModeKey = 'theme_mode';
  static const _kSeedColorKey = 'seed_color';

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = const Color(0xFF448AFF);

  ThemeProvider() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );

  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSeedColorKey, color.value);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIdx = prefs.getInt(_kThemeModeKey);
    final colorVal = prefs.getInt(_kSeedColorKey);
    if (modeIdx != null && modeIdx >= 0 && modeIdx < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[modeIdx];
    }
    if (colorVal != null) {
      _seedColor = Color(colorVal);
    }
    notifyListeners();
  }
}


