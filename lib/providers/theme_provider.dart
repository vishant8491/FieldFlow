import 'package:flutter/material.dart';

import '../services/database_service.dart';

class ThemeProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    loadThemePreference();
  }

  Future<void> loadThemePreference() async {
    try {
      final saved = await _db.getPreference('themeMode');
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    } catch (_) {
      _themeMode = ThemeMode.system;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      String value = 'system';
      if (mode == ThemeMode.light) value = 'light';
      if (mode == ThemeMode.dark) value = 'dark';
      await _db.setPreference('themeMode', value);
    } catch (_) {}
  }
}
