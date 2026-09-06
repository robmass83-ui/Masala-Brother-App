import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../connectivity/connectivity_provider.dart';
import '../notifications/task_notifications.dart';
import '../prefs/settings_providers.dart';
import '../../features/settings/update_flow.dart';
import '../../router/navigator_keys.dart';
import 'app_updater.dart';
import 'available_update_provider.dart';

/// Checks GitHub for a newer APK when the signed-in shell is visible or resumed.
class UpdateProbe extends ConsumerStatefulWidget {
  const UpdateProbe({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateProbe> createState() => _UpdateProbeState();
}

class _UpdateProbeState extends ConsumerState<UpdateProbe>
    with WidgetsBindingObserver {
  bool _promptedThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TaskNotifications.onUpdateNotificationTap = _openFromNotification;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(prompt: true));
  }

  @override
  void dispose() {
    if (TaskNotifications.onUpdateNotificationTap == _openFromNotification) {
      TaskNotifications.onUpdateNotificationTap = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check(prompt: true);
    }
  }

  Future<void> _check({required bool prompt}) async {
    final online = ref.read(isOnlineProvider).valueOrNull ?? true;
    if (!online) return;
    final latest = await ref.read(availableUpdateProvider.notifier).check();
    if (!prompt || !mounted || latest == null) return;
    final dismissed = ref.read(appPrefsProvider).dismissedUpdateVersion;
    if (!AppUpdater.shouldPrompt(
      latest: latest,
      currentVersion: AppConfig.appVersion,
      dismissedVersion: dismissed,
    )) {
      return;
    }
    if (_promptedThisSession) return;
    _promptedThisSession = true;
    final accepted = await offerAvailableUpdate(context, latest);
    if (accepted || !mounted) return;
    await ref.read(availableUpdateProvider.notifier).rememberDismissed();
  }

  void _openFromNotification() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final cached = ref.read(availableUpdateProvider);
    if (cached != null) {
      offerAvailableUpdate(ctx, cached);
      return;
    }
    checkAppUpdates(ctx);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
