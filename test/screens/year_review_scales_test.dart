// Year in Review graded attendance on moving scales (lens audit finding 5):
// the monthly bars rescaled to whichever month was fullest, the heatmap
// scrolled off after May at phone width, and STREAK and RATE were printed
// twice at two precisions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/screens/year_review_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;

  setUp(() async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({'crt_effects': false});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  Map<String, List<Clip>> days(int year, Map<int, int> daysPerMonth,
      {int clipsPerDay = 1}) {
    final out = <String, List<Clip>>{};
    daysPerMonth.forEach((month, n) {
      for (var d = 1; d <= n; d++) {
        final date =
            '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        out[date] = [
          for (var i = 0; i < clipsPerDay; i++)
            Clip(
              id: '$date-$i',
              date: date,
              filePath: 'nonexistent/$date-$i.mp4',
              type: ClipType.video,
              createdAt: DateTime(year, month, d),
            ),
        ];
      }
    });
    return out;
  }

  Future<void> pump(WidgetTester tester, Map<String, List<Clip>> clips) async {
    storage.setClipsForTest(clips);
    // Tall enough that the ListView builds every section.
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: YearReviewScreen(storageService: storage),
    ));
    await tester.pump();
  }

  double barHeight(WidgetTester tester, int monthIndex) =>
      tester.getSize(find.byKey(ValueKey('month-bar-$monthIndex'))).height;

  testWidgets('a month keeps its bar height whatever the fullest month is',
      (tester) async {
    await pump(tester, days(2025, {1: 10, 2: 5}));
    final janAlone = barHeight(tester, 0);
    await pump(tester, days(2025, {1: 10, 2: 28}));
    final janBesideFullFeb = barHeight(tester, 0);
    expect(janBesideFullFeb, closeTo(janAlone, 0.5),
        reason: 'the scale moved with February');
    // Fixed scale, labelled once: a full month is the full bar.
    expect(find.textContaining('out of 31'), findsOneWidget);
  });

  testWidgets('bars count days captured, not clips', (tester) async {
    await pump(tester, days(2025, {1: 10}, clipsPerDay: 3));
    final threeClipsADay = barHeight(tester, 0);
    await pump(tester, days(2025, {1: 10}));
    expect(barHeight(tester, 0), closeTo(threeClipsADay, 0.5));
  });

  testWidgets('the whole year fits the heatmap at 360 dp, no sideways scroll',
      (tester) async {
    await pump(tester, days(2025, {12: 31}));
    final grid = find.byKey(const ValueKey('heatmap-grid'));
    expect(grid, findsOneWidget);
    expect(tester.getRect(grid).right, lessThanOrEqualTo(360 - 16));
    final horizontal = find.ancestor(
        of: grid,
        matching: find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal));
    expect(horizontal, findsNothing);
    // Rows a few pixels tall can't hold weekday letters; they give way
    // rather than pile on top of each other.
    expect(find.text('W'), findsNothing);
  });

  testWidgets('streak and rate are each stated once', (tester) async {
    await pump(tester, days(2025, {1: 10}));
    expect(find.textContaining('STREAK'), findsOneWidget);
    expect(find.textContaining('RATE'), findsOneWidget);
    // One precision: whole percent (10 of 365 days).
    expect(find.text('3%'), findsOneWidget);
  });
}
