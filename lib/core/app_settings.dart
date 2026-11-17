
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  late SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('ar');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final theme = _prefs.getString('theme_mode') ?? 'system';
    final language = _prefs.getString('language') ?? 'ar';

    _themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    _locale = Locale(language);
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;

    await _prefs.setString(
      'theme_mode',
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      },
    );

    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _locale = Locale(language);
    await _prefs.setString('language', language);
    notifyListeners();
  }
}

final appSettings = AppSettings();
