import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../notifications/task_notifications.dart';
import '../prefs/settings_providers.dart';
import 'app_updater.dart';

final appUpdaterProvider = Provider<AppUpdater>((ref) => AppUpdater());

/// Latest GitHub release that is newer than the installed app, or null.
final availableUpdateProvider =
    NotifierProvider<AvailableUpdateNotifier, AppUpdate?>(
  AvailableUpdateNotifier.new,
);

class AvailableUpdateNotifier extends Notifier<AppUpdate?> {
  DateTime? _lastCheckAt;
  bool _checking = false;

  @override
  AppUpdate? build() => null;

  /// Silent GitHub check. Never throws. Skipped in widget tests and on web.
  Future<AppUpdate?> check({Duration minInterval = const Duration(minutes: 15)}) async {
    if (kIsWeb || _runningUnderTest) return state;
    if (_checking) return state;
    final now = DateTime.now();
    final last = _lastCheckAt;
    if (last != null && now.difference(last) < minInterval) return state;

    _checking = true;
    _lastCheckAt = now;
    try {
      final latest = await ref.read(appUpdaterProvider).fetchLatest();
      if (latest == null ||
          !AppUpdater.isNewer(latest.version, AppConfig.appVersion)) {
        state = null;
        return null;
      }
      state = latest;
      final prefs = ref.read(appPrefsProvider);
      if (AppUpdater.shouldNotify(
        latest: latest,
        currentVersion: AppConfig.appVersion,
        lastNotifiedVersion: prefs.lastNotifiedUpdateVersion,
      )) {
        await TaskNotifications.showUpdateAvailable(latest.version);
        await prefs.setLastNotifiedUpdateVersion(latest.version);
      }
      return latest;
    } catch (e) {
      debugPrint('Update check: $e');
      return state;
    } finally {
      _checking = false;
    }
  }

  Future<void> rememberDismissed() async {
    final version = state?.version;
    if (version == null) return;
    await ref.read(appPrefsProvider).setDismissedUpdateVersion(version);
  }

  static bool get _runningUnderTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
}
