import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/meal_entry.dart';
import '../models/workout_entry.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _mealChannel = AndroidNotificationChannel(
    'meal_reminders',
    'Meal reminders',
    description: 'Meal schedule notifications',
    importance: Importance.high,
  );

  static const _gymChannel = AndroidNotificationChannel(
    'gym_reminders',
    'Gym reminders',
    description: 'Workout schedule notifications',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;

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

  Future<void> scheduleMealReminders(List<MealSchedule> schedules) async {
    await initialize();
    await _cancelIdsInRange(10_000, 20_000);

    for (final schedule in schedules.where((m) => m.enabled)) {
      final id = 10_000 + schedule.id.hashCode.abs() % 9_999;
      final firstDate = _nextOccurrence(
        hour: schedule.hour,
        minute: schedule.minute,
      );

      await _plugin.zonedSchedule(
        id,
        'Meal reminder',
        'Time for ${schedule.title}',
        firstDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_reminders',
            'Meal reminders',
            channelDescription: 'Meal schedule notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> scheduleGymReminders(List<GymSchedule> schedules) async {
    await initialize();
    await _cancelIdsInRange(20_000, 30_000);

    for (final schedule in schedules.where((g) => g.enabled)) {
      final id = 20_000 + schedule.id.hashCode.abs() % 9_999;
      final firstDate = _nextWeekdayOccurrence(
        weekday: schedule.weekday,
        hour: schedule.hour,
        minute: schedule.minute,
      );

      await _plugin.zonedSchedule(
        id,
        'Gym reminder',
        'Workout: ${schedule.title}',
        firstDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'gym_reminders',
            'Gym reminders',
            channelDescription: 'Workout schedule notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _cancelIdsInRange(int from, int to) async {
    for (var id = from; id <= to; id++) {
      await _plugin.cancel(id);
    }
  }

  tz.TZDateTime _nextOccurrence({required int hour, required int minute}) {
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
    if (!kDebugMode) return;
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
