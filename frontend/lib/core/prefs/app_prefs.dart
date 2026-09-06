import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local settings: theme override and default reminder hour.
class AppPrefs {
  AppPrefs({
    this.themeMode = ThemeMode.system,
    this.reminderHour = 9,
    this._store,
  });

  factory AppPrefs.memory({
    ThemeMode themeMode = ThemeMode.system,
    int reminderHour = 9,
  }) {
    return AppPrefs(themeMode: themeMode, reminderHour: reminderHour);
  }

  static const _themeKey = 'theme_mode';
  static const _hourKey = 'reminder_hour';

  SharedPreferences? _store;
  ThemeMode themeMode;
  int reminderHour;

  static Future<AppPrefs> load() async {
    try {
      final store = await SharedPreferences.getInstance();
      return AppPrefs(
        themeMode: _parseTheme(store.getString(_themeKey)),
        reminderHour: _clampHour(store.getInt(_hourKey) ?? 9),
        store: store,
      );
    } catch (_) {
      return AppPrefs.memory();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _store?.setString(_themeKey, mode.name);
  }

  Future<void> setReminderHour(int hour) async {
    reminderHour = _clampHour(hour);
    await _store?.setInt(_hourKey, reminderHour);
  }

  static ThemeMode _parseTheme(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static int _clampHour(int hour) => hour.clamp(0, 23);
}
