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

  /// Last schedule applied, so rebuilds with the same tasks do nothing.
  static String? _lastScheduleKey;
  static Future<void> _syncChain = Future<void>.value();

  /// Reschedules reminders. Calls are serialized (two overlapping syncs used
  /// to clash), and alarms are cancelled from the system's own pending list,
  /// so reminders left from before an app restart for tasks done, deleted or
  /// reassigned meanwhile no longer fire.
  static Future<void> sync({
    required List<HouseholdTask> tasks,
    required String currentUid,
    int hour = 9,
  }) {
    _syncChain = _syncChain
        .then((_) => _sync(tasks: tasks, currentUid: currentUid, hour: hour))
        .catchError((Object e) {
      debugPrint('TaskNotifications sync: $e');
    });
    return _syncChain;
  }

  static Future<void> _sync({
    required List<HouseholdTask> tasks,
    required String currentUid,
    required int hour,
  }) async {
    if (!_ready) return;
    try {
      final loc = tz.getLocation('Europe/Rome');
      final now = tz.TZDateTime.now(loc);
      final wanted = <({int id, String taskId, String title, tz.TZDateTime at})>[];
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
        if (!scheduled.isAfter(now)) continue;
        wanted.add((
          id: _taskNotificationId(task.id),
          taskId: task.id,
          title: task.title,
          at: scheduled,
        ));
      }
      final key = (wanted.map((w) => '${w.id}|${w.at}|${w.title}').toList()..sort())
          .join(';');
      if (key == _lastScheduleKey) return;

      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id == updateNotificationId) continue;
        await _plugin.cancel(p.id);
      }
      for (final w in wanted) {
        await _plugin.zonedSchedule(
          w.id,
          'Promemoria',
          w.title,
          w.at,
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
          payload: w.taskId,
        );
      }
      _lastScheduleKey = key;
    } catch (e, st) {
      debugPrint('TaskNotifications sync: $e\n$st');
    }
  }
}
