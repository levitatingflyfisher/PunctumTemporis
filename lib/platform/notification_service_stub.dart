import 'package:flutter/material.dart';

/// Web stub: push notifications are not available on web in this release.
/// All methods are no-ops.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> initialize() async {}

  Future<void> scheduleDailyReminder(TimeOfDay time) async {}

  Future<void> cancelReminder() async {}
}
