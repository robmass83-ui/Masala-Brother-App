import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/task_models.dart';
import '../../router/navigator_keys.dart';

/// Local reminders at the configured hour (default 09:00 Europe/Rome). No FCM.
class TaskNotifications {
  TaskNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

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
        _openTask(payload);
      }
    } catch (e, st) {
      debugPrint('TaskNotifications init: $e\n$st');
    }
  }

  static void _onTap(NotificationResponse response) {
    final id = response.payload;
    if (id == null || id.isEmpty) return;
    _openTask(id);
  }

  static void _openTask(String taskId) {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      GoRouter.of(ctx).push('/dafare/$taskId');
    });
  }

  static Future<void> sync({
    required List<HouseholdTask> tasks,
    required String currentUid,
    int hour = 9,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
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
        await _plugin.zonedSchedule(
          task.id.hashCode & 0x7fffffff,
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
      }
    } catch (e, st) {
      debugPrint('TaskNotifications sync: $e\n$st');
    }
  }
}
