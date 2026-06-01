import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'one_second_reminder';
  static const _channelName = 'Daily Reminder';
  static const _notificationId = 1001;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    if (!_initialized) await initialize();

    await cancelReminder();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily reminder to capture your one second',
      importance: Importance.high,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      _notificationId,
      'One Second A Day',
      _buildNotificationText(),
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder() async {
    await _plugin.cancel(_notificationId);
  }

  String _buildNotificationText() {
    final messages = [
      "Capture your one second today!",
      "Don't forget to freeze a moment today!",
      "Your future self will thank you. Record your second!",
      "A second a day keeps the memories in play!",
      "Time to capture today's moment!",
    ];
    // Rotate based on day of year for variety
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return messages[dayOfYear % messages.length];
  }
}
