import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/meal_entry.dart';
import '../models/workout_entry.dart';

class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsEnabled;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _mealChannel = AndroidNotificationChannel(
    'meal_reminders_alarm',
    'Meal reminders',
    description: 'Meal schedule notifications',
    importance: Importance.max,
  );

  static const _gymChannel = AndroidNotificationChannel(
    'gym_reminders_alarm',
    'Gym reminders',
    description: 'Workout schedule notifications',
    importance: Importance.max,
  );

  static const int _mealIdStart = 10_000;
  static const int _mealIdEndExclusive = 20_000;
  static const int _gymIdStart = 20_000;
  static const int _gymIdEndExclusive = 30_000;

  bool get _supportsScheduledLocalNotifications => !kIsWeb;

  Future<void> initialize() async {
    if (_initialized) return;

    if (!_supportsScheduledLocalNotifications) {
      _initialized = true;
      return;
    }

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: iOS);

    await _plugin.initialize(settings);

    final androidPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlatform?.createNotificationChannel(_mealChannel);
    await androidPlatform?.createNotificationChannel(_gymChannel);
    await androidPlatform?.requestNotificationsPermission();
    await androidPlatform?.requestExactAlarmsPermission();

    final iosPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlatform?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;
  }

  Future<NotificationPermissionStatus> getPermissionStatus({
    bool requestIfNeeded = false,
  }) async {
    if (!_supportsScheduledLocalNotifications) {
      return const NotificationPermissionStatus(
        notificationsEnabled: false,
        exactAlarmsEnabled: false,
      );
    }

    await initialize();

    var notificationsEnabled = true;
    var exactAlarmsEnabled = true;

    final androidPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlatform != null) {
      notificationsEnabled =
          await androidPlatform.areNotificationsEnabled() ?? true;
      if (!notificationsEnabled && requestIfNeeded) {
        await androidPlatform.requestNotificationsPermission();
        notificationsEnabled =
            await androidPlatform.areNotificationsEnabled() ?? false;
      }

      exactAlarmsEnabled =
          await androidPlatform.canScheduleExactNotifications() ?? true;
      if (!exactAlarmsEnabled && requestIfNeeded) {
        await androidPlatform.requestExactAlarmsPermission();
        exactAlarmsEnabled =
            await androidPlatform.canScheduleExactNotifications() ?? false;
      }
    }

    final iosPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlatform != null) {
      var iosPermissions = await iosPlatform.checkPermissions();
      notificationsEnabled = iosPermissions?.isEnabled ?? false;

      if (!notificationsEnabled && requestIfNeeded) {
        await iosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        iosPermissions = await iosPlatform.checkPermissions();
        notificationsEnabled = iosPermissions?.isEnabled ?? false;
      }
    }

    return NotificationPermissionStatus(
      notificationsEnabled: notificationsEnabled,
      exactAlarmsEnabled: exactAlarmsEnabled,
    );
  }

  Future<void> scheduleMealReminders(List<MealSchedule> schedules) async {
    if (!_supportsScheduledLocalNotifications) {
      return;
    }

    await initialize();
    final permissionStatus = await getPermissionStatus(requestIfNeeded: true);
    if (!permissionStatus.notificationsEnabled) {
      debugPrint(
        'Notifications are disabled: meal reminders were not scheduled.',
      );
      return;
    }

    await _cancelIdsInRange(_mealIdStart, _mealIdEndExclusive);

    final enabledSchedules = schedules.where((m) => m.enabled).toList();
    for (var i = 0; i < enabledSchedules.length; i++) {
      final schedule = enabledSchedules[i];
      final id = _mealIdStart + i;
      final firstDate = _nextDailyMealOccurrence(
        hour: schedule.hour,
        minute: schedule.minute,
      );

      await _scheduleWithFallback(
        id,
        'Meal reminder',
        'Time for ${schedule.title}',
        firstDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_reminders_alarm',
            'Meal reminders',
            channelDescription: 'Meal schedule notifications',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> scheduleGymReminders(List<GymSchedule> schedules) async {
    if (!_supportsScheduledLocalNotifications) {
      return;
    }

    await initialize();
    final permissionStatus = await getPermissionStatus(requestIfNeeded: true);
    if (!permissionStatus.notificationsEnabled) {
      debugPrint(
        'Notifications are disabled: gym reminders were not scheduled.',
      );
      return;
    }

    await _cancelIdsInRange(_gymIdStart, _gymIdEndExclusive);

    final enabledSchedules = schedules.where((g) => g.enabled).toList();
    for (var i = 0; i < enabledSchedules.length; i++) {
      final schedule = enabledSchedules[i];
      final id = _gymIdStart + i;
      final firstDate = _nextWeekdayOccurrence(
        weekday: schedule.weekday,
        hour: schedule.hour,
        minute: schedule.minute,
      );

      await _scheduleWithFallback(
        id,
        'Gym reminder',
        'Workout: ${schedule.title}',
        firstDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'gym_reminders_alarm',
            'Gym reminders',
            channelDescription: 'Workout schedule notifications',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.reminder,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _scheduleWithFallback(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Exact notification scheduling unavailable, retrying inexactly: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }
  }

  Future<void> _cancelIdsInRange(int from, int to) async {
    final pending = await _plugin.pendingNotificationRequests();
    final idsToCancel = pending
        .map((item) => item.id)
        .where((id) => id >= from && id < to)
        .toList();

    for (final id in idsToCancel) {
      await _plugin.cancel(id);
    }
  }

  tz.TZDateTime _nextDailyMealOccurrence({
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextWeekdayOccurrence({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> debugNotificationNow() async {
    if (!kDebugMode || !_supportsScheduledLocalNotifications) return;
    await _plugin.show(
      999,
      'Debug notification',
      'If this appears, notifications are configured correctly.',
      const NotificationDetails(
        android: AndroidNotificationDetails('debug', 'Debug'),
      ),
    );
  }
}
