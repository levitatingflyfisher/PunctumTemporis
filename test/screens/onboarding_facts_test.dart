// Onboarding was three pages of pitch that taught no model (audit finding
// 8). Ruling: lead with three facts (clips are files on this phone,
// nothing uploads, missing days is normal) and offer the daily reminder on
// the last page (finding 9's shared ground: offered, not switched on).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/onboarding_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;
  final scheduled = <TimeOfDay>[];

  setUp(() async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    scheduled.clear();
  });

  Future<void> pump(WidgetTester tester, {VoidCallback? onComplete}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: OnboardingScreen(
        key: UniqueKey(),
        storageService: storage,
        onComplete: onComplete ?? () {},
        scheduleReminder: (t) async => scheduled.add(t),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the first page states the three facts', (tester) async {
    await pump(tester);
    final words = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(words, contains('file on this phone'));
    expect(words, contains('Nothing is uploaded'));
    expect(words, contains('Missing a day is normal'));
  });

  Future<void> toLastPage(WidgetTester tester) async {
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
  }

  testWidgets('the last page offers the reminder, off until chosen',
      (tester) async {
    await pump(tester);
    await toLastPage(tester);
    final sw = find.widgetWithText(SwitchListTile, 'Remind me each day at 8:00 PM');
    expect(sw, findsOneWidget);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);

    var done = false;
    await pump(tester, onComplete: () => done = true);
    await toLastPage(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Remind me each day at 8:00 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(storage.getReminderEnabled(), isTrue);
    expect(scheduled, [const TimeOfDay(hour: 20, minute: 0)]);
  });

  testWidgets('declining leaves the reminder off and schedules nothing',
      (tester) async {
    await pump(tester);
    await toLastPage(tester);
    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();
    expect(storage.getReminderEnabled(), isFalse);
    expect(scheduled, isEmpty);
  });

  testWidgets('every page holds at 320 dp and 3x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: OnboardingScreen(
          storageService: storage,
          onComplete: () {},
          scheduleReminder: (t) async {}),
    ));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(tester.takeException(), isNull, reason: 'page $i');
      if (i < 2) {
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }
    }
  });
}
