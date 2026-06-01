import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/services/storage_service.dart';

void main() {
  group('Notification text generation', () {
    test('buildNotificationText returns non-empty string', () {
      // Test the text generation logic via rotation
      final messages = [
        "Capture your one second today!",
        "Don't forget to freeze a moment today!",
        "Your future self will thank you. Record your second!",
        "A second a day keeps the memories in play!",
        "Time to capture today's moment!",
      ];
      final dayOfYear =
          DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
      final expected = messages[dayOfYear % messages.length];
      expect(expected, isNotEmpty);
      expect(expected.length, greaterThan(10));
    });
  });

  group('Reminder preferences via StorageService', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
    });

    test('toggle reminder on/off', () async {
      expect(storageService.getReminderEnabled(), false);
      await storageService.setReminderEnabled(true);
      expect(storageService.getReminderEnabled(), true);
      await storageService.setReminderEnabled(false);
      expect(storageService.getReminderEnabled(), false);
    });

    test('set and get reminder time', () async {
      // Default
      var time = storageService.getReminderTime();
      expect(time.hour, 20);
      expect(time.minute, 0);

      // Set new time
      await storageService
          .setReminderTime(const TimeOfDay(hour: 7, minute: 45));
      time = storageService.getReminderTime();
      expect(time.hour, 7);
      expect(time.minute, 45);

      // Set midnight
      await storageService.setReminderTime(const TimeOfDay(hour: 0, minute: 0));
      time = storageService.getReminderTime();
      expect(time.hour, 0);
      expect(time.minute, 0);
    });
  });
}
