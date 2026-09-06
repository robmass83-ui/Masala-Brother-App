import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local settings: theme override, reminder hour, and update prompts.
class AppPrefs {
  AppPrefs({
    this.themeMode = ThemeMode.system,
    this.reminderHour = 9,
    this.lastNotifiedUpdateVersion,
    this.dismissedUpdateVersion,
    SharedPreferences? store,
  }) : _store = store;

  factory AppPrefs.memory({
    ThemeMode themeMode = ThemeMode.system,
    int reminderHour = 9,
    String? lastNotifiedUpdateVersion,
    String? dismissedUpdateVersion,
  }) {
    return AppPrefs(
      themeMode: themeMode,
      reminderHour: reminderHour,
      lastNotifiedUpdateVersion: lastNotifiedUpdateVersion,
      dismissedUpdateVersion: dismissedUpdateVersion,
    );
  }

  static const _themeKey = 'theme_mode';
  static const _hourKey = 'reminder_hour';
  static const _notifiedUpdateKey = 'last_notified_update_version';
  static const _dismissedUpdateKey = 'dismissed_update_version';

  SharedPreferences? _store;
  ThemeMode themeMode;
  int reminderHour;
  String? lastNotifiedUpdateVersion;
  String? dismissedUpdateVersion;

  static Future<AppPrefs> load() async {
    try {
      final store = await SharedPreferences.getInstance();
      return AppPrefs(
        themeMode: _parseTheme(store.getString(_themeKey)),
        reminderHour: _clampHour(store.getInt(_hourKey) ?? 9),
        lastNotifiedUpdateVersion: store.getString(_notifiedUpdateKey),
        dismissedUpdateVersion: store.getString(_dismissedUpdateKey),
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

  Future<void> setLastNotifiedUpdateVersion(String version) async {
    lastNotifiedUpdateVersion = version;
    await _store?.setString(_notifiedUpdateKey, version);
  }

  Future<void> setDismissedUpdateVersion(String version) async {
    dismissedUpdateVersion = version;
    await _store?.setString(_dismissedUpdateKey, version);
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
