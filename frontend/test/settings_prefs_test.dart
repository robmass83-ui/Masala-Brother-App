import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brotherapp/core/prefs/app_prefs.dart';
import 'package:brotherapp/core/utils/date_format.dart';
import 'package:brotherapp/core/connectivity/connectivity_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:brotherapp/data/trash_models.dart';

void main() {
  test('AppPrefs.memory keeps theme and reminder hour', () async {
    final prefs = AppPrefs.memory();
    expect(prefs.themeMode, ThemeMode.system);
    expect(prefs.reminderHour, 9);
    await prefs.setThemeMode(ThemeMode.dark);
    await prefs.setReminderHour(7);
    expect(prefs.themeMode, ThemeMode.dark);
    expect(prefs.reminderHour, 7);
    await prefs.setReminderHour(30);
    expect(prefs.reminderHour, 23);
    await prefs.setLastNotifiedUpdateVersion('1.0.2');
    await prefs.setDismissedUpdateVersion('1.0.2');
    expect(prefs.lastNotifiedUpdateVersion, '1.0.2');
    expect(prefs.dismissedUpdateVersion, '1.0.2');
  });

  test('AppPrefs.load reads SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'light',
      'reminder_hour': 8,
      'last_notified_update_version': '1.0.3',
      'dismissed_update_version': '1.0.3',
    });
    final prefs = await AppPrefs.load();
    expect(prefs.themeMode, ThemeMode.light);
    expect(prefs.reminderHour, 8);
    expect(prefs.lastNotifiedUpdateVersion, '1.0.3');
    expect(prefs.dismissedUpdateVersion, '1.0.3');
  });

  test('AppDateFormat.relative uses Italian short forms', () async {
    await AppDateFormat.ensureInitialized();
    final now = DateTime(2026, 9, 5, 12, 0);
    expect(AppDateFormat.relative(now, now: now), 'adesso');
    expect(
      AppDateFormat.relative(now.subtract(const Duration(minutes: 3)), now: now),
      '3 min fa',
    );
    expect(
      AppDateFormat.relative(now.subtract(const Duration(hours: 5)), now: now),
      '5 h fa',
    );
    expect(
      AppDateFormat.relative(now.subtract(const Duration(days: 1)), now: now),
      'ieri',
    );
  });

  test('withinTrashRetention keeps 30 days and drops older', () {
    final now = DateTime(2026, 9, 5);
    expect(withinTrashRetention(now.subtract(const Duration(days: 29)), now: now), isTrue);
    expect(withinTrashRetention(now.subtract(const Duration(days: 31)), now: now), isFalse);
    expect(withinTrashRetention(null, now: now), isFalse);
  });

  test('connectivityIsOnline is false only when all results are none', () {
    expect(connectivityIsOnline([ConnectivityResult.wifi]), isTrue);
    expect(connectivityIsOnline([ConnectivityResult.none]), isFalse);
    expect(connectivityIsOnline(const []), isFalse);
    expect(
      connectivityIsOnline([ConnectivityResult.none, ConnectivityResult.mobile]),
      isTrue,
    );
  });
}
