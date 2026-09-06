import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/task_models.dart';
import '../../router/navigator_keys.dart';

/// Local reminders at the configured hour (default 09:00 Europe/Rome). No FCM.
/// Also posts a one-shot Android notification when a GitHub app update is ready.
class TaskNotifications {
  TaskNotifications._();

  static const updatePayload = 'app-update';
  static const updateNotificationId = 71001;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final Set<int> _scheduledTaskIds = <int>{};
  static bool _ready = false;

  /// Set from the update probe so tapping the system notification opens the APK dialog.
  static VoidCallback? onUpdateNotificationTap;

  static Future<void> ensureInitialized() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: _onTap,
      );
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      _ready = true;

      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.isNotEmpty) {
        _handlePayload(payload);
      }
    } catch (e, st) {
      debugPrint('TaskNotifications init: $e\n$st');
    }
  }

  static void _onTap(NotificationResponse response) {
    final id = response.payload;
    if (id == null || id.isEmpty) return;
    _handlePayload(id);
  }

  static void _handlePayload(String payload) {
    if (payload == updatePayload) {
      _openUpdate();
      return;
    }
    _openTask(payload);
  }

  static void _openUpdate() {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      onUpdateNotificationTap?.call();
    });
  }

  static void _openTask(String taskId) {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      GoRouter.of(ctx).push('/dafare/$taskId');
    });
  }

  static Future<void> showUpdateAvailable(String version) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        updateNotificationId,
        'Aggiornamento disponibile',
        'La versione $version è pronta. Tocca per installare.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'app_updates',
            'Aggiornamenti app',
            channelDescription:
                'Avvisa quando c’è una nuova versione da installare',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        payload: updatePayload,
      );
    } catch (e, st) {
      debugPrint('TaskNotifications update: $e\n$st');
    }
  }

  static int _taskNotificationId(String taskId) {
    var id = taskId.hashCode & 0x7fffffff;
    if (id == updateNotificationId) {
      id = (id + 1) & 0x7fffffff;
    }
    return id;
  }

  static Future<void> sync({
    required List<HouseholdTask> tasks,
    required String currentUid,
    int hour = 9,
  }) async {
    if (!_ready) return;
    try {
      for (final id in _scheduledTaskIds) {
        await _plugin.cancel(id);
      }
      _scheduledTaskIds.clear();
      final loc = tz.getLocation('Europe/Rome');
      for (final task in tasks) {
        if (task.done || task.isDeleted) continue;
        final assignee = task.assigneeUid;
        if (assignee != null && assignee != currentUid) continue;
        final when = reminderAt(
          dueDate: task.dueDate,
          reminderDaysBefore: task.reminderDaysBefore,
          hour: hour,
        );
        if (when == null) continue;
        final scheduled = tz.TZDateTime(
          loc,
          when.year,
          when.month,
          when.day,
          when.hour,
        );
        if (!scheduled.isAfter(tz.TZDateTime.now(loc))) continue;
        final id = _taskNotificationId(task.id);
        await _plugin.zonedSchedule(
          id,
          'Promemoria',
          task.title,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders',
              'Promemoria cose da fare',
              channelDescription: 'Scadenze di Roberto e Laura',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: task.id,
        );
        _scheduledTaskIds.add(id);
      }
    } catch (e, st) {
      debugPrint('TaskNotifications sync: $e\n$st');
    }
  }
}
