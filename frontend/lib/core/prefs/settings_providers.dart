import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_prefs.dart';

final appPrefsProvider = Provider<AppPrefs>((ref) => AppPrefs.memory());

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(appPrefsProvider).themeMode;

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(appPrefsProvider).setThemeMode(mode);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ReminderHourController extends Notifier<int> {
  @override
  int build() => ref.watch(appPrefsProvider).reminderHour;

  Future<void> setHour(int hour) async {
    final clamped = hour.clamp(0, 23);
    state = clamped;
    await ref.read(appPrefsProvider).setReminderHour(clamped);
  }
}

final reminderHourProvider =
    NotifierProvider<ReminderHourController, int>(ReminderHourController.new);

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'Sistema',
      ThemeMode.light => 'Chiaro',
      ThemeMode.dark => 'Scuro',
    };
