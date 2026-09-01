// Streak milestones (lens audit finding 3; operator ruling on streaks and
// badges: keep the rewards, fix them; nothing earned is revoked).
//
// Before: a milestone opened a modal Dialog with a single AWESOME button
// whose only effect was to close it, standing between the person and the
// calendar cell they came back to see. Six lenses agreed the modal goes.
// Now the milestone is acknowledged in the calendar itself: a line the
// person can read or ignore, closed with a plain Close, and the milestone
// stays recorded as earned whatever they do.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/screens/calendar_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/utils/date_format_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;

  Future<void> setUpStreak(int days, {List<String> celebrated = const []})
      async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({
      'crt_effects': false,
      'onboarding_complete': true,
      'celebrated_milestones': celebrated,
    });
    storage = StorageService(await SharedPreferences.getInstance());
    final now = DateTime.now();
    final clips = <String, List<Clip>>{};
    for (var i = 0; i < days; i++) {
      final d = DateTime(now.year, now.month, now.day - i);
      final key = DateFormatUtil.format(d, DateFormatOption.isoDate);
      clips[key] = [
        Clip(
          id: 'c$i',
          date: key,
          filePath: 'nonexistent/c$i.mp4',
          type: ClipType.video,
          createdAt: d,
        ),
      ];
    }
    storage.setClipsForTest(clips);
  }

  Future<void> pumpCalendar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: CalendarScreen(storageService: storage, onThemeChanged: (_, __) {}),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a new milestone is a line in the calendar, not a modal',
      (tester) async {
    await setUpStreak(7);
    await pumpCalendar(tester);

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('AWESOME'), findsNothing);
    expect(find.textContaining('7 days in a row'), findsOneWidget);
    // The calendar is still there to be used underneath nothing.
    expect(find.text('CAPTURE'), findsOneWidget);
  });

  testWidgets('Close puts it away and the milestone stays earned',
      (tester) async {
    await setUpStreak(7);
    await pumpCalendar(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.textContaining('7 days in a row'), findsNothing);
    expect(storage.getCelebratedMilestones(), contains(7));
  });

  testWidgets('an already-earned milestone is not announced again',
      (tester) async {
    await setUpStreak(7, celebrated: ['7']);
    await pumpCalendar(tester);
    expect(find.textContaining('days in a row'), findsNothing);
  });

  testWidgets('no milestone, no line', (tester) async {
    await setUpStreak(3);
    await pumpCalendar(tester);
    expect(find.textContaining('days in a row'), findsNothing);
  });
}
