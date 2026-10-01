// Today and captured used to share one mark (lens audit finding 4): a
// captured day and today both painted the same 2px primary border, so on
// the day the app exists for, capturing today erased the today marker. The
// camera-date flag was an 8px amber square explained nowhere.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/screens/calendar_screen.dart';
import 'package:one_second_a_day/screens/clip_preview_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  late StorageService storage;

  setUp(() async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({'crt_effects': false});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  Future<void> pump(WidgetTester tester, Map<String, List<Clip>> clips) async {
    storage.setClipsForTest(clips);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: CalendarScreen(storageService: storage, onThemeChanged: (_, __) {}),
    ));
    await tester.pumpAndSettle();
  }

  Clip clipOn(String date, {String? exifDate}) => Clip(
        id: 'c-$date',
        date: date,
        filePath: 'nonexistent/$date.mp4',
        type: ClipType.video,
        createdAt: DateTime.now(),
        exifDate: exifDate,
      );

  testWidgets('today keeps its mark before and after it is captured',
      (tester) async {
    final today = _iso(DateTime.now());
    await pump(tester, {});
    expect(find.byKey(const ValueKey('today-mark')), findsOneWidget,
        reason: 'uncaptured today is marked');

    await pump(tester, {today: [clipOn(today)]});
    expect(find.byKey(const ValueKey('today-mark')), findsOneWidget,
        reason: 'capturing today must not erase the today mark');
  });

  testWidgets('a past captured day carries no today mark', (tester) async {
    final now = DateTime.now();
    // A captured day other than today, in the visible month.
    final other = now.day > 1
        ? DateTime(now.year, now.month, now.day - 1)
        : DateTime(now.year, now.month, now.day);
    if (other.day == now.day) return; // first of the month: nothing to compare
    final date = _iso(other);
    await pump(tester, {date: [clipOn(date)]});
    // Only today's cell has the mark, and today is uncaptured here.
    expect(find.byKey(const ValueKey('today-mark')), findsOneWidget);
  });

  testWidgets('the camera-date flag is a named glyph, not a bare square',
      (tester) async {
    final now = DateTime.now();
    final date = _iso(now);
    await pump(tester, {
      date: [clipOn(date, exifDate: '2001-01-01')],
    });
    final flag = find.byKey(const ValueKey('camera-date-flag'));
    expect(flag, findsOneWidget);
    expect(find.descendant(of: flag, matching: find.byType(Icon)),
        findsOneWidget);
    expect(
        find.bySemanticsLabel(RegExp('filmed on another day', caseSensitive: false)),
        findsOneWidget);
  });

  testWidgets('the clip view says when a clip was filmed on another day',
      (tester) async {
    final clip = clipOn('2026-09-04', exifDate: '2026-08-30');
    storage.setClipsForTest({'2026-09-04': [clip]});
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: ClipPreviewScreen(storageService: storage, clip: clip),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.textContaining(RegExp('FILMED.*AUG 30')), findsOneWidget);
  });
}
