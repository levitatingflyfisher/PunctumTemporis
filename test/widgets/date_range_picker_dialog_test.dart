import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/widgets/date_range_picker_dialog.dart';
import 'package:one_second_a_day/widgets/thumbnail_image.dart';

Future<StorageService> _makeSvc() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return StorageService(prefs);
}

Widget _dialogFor(StorageService svc, DateTime month) => MaterialApp(
      theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
      home: Scaffold(
        body: RetroDateRangePickerDialog(
          storageService: svc,
          initialRange: DateTimeRange(
            start: DateTime(month.year, month.month, 1),
            end: DateTime(month.year, month.month + 1, 0),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.visualStyle = 'retro';
  });

  group('Date range picker grid', () {
    testWidgets('calendar grid height is the same for 4-row and 5-row months',
        (tester) async {
      // Use a taller screen so the dialog fits without overflow
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final svc = await _makeSvc();

      // February 2026: 28 days starting Sunday = exactly 4 rows
      await tester.pumpWidget(_dialogFor(svc, DateTime(2026, 2)));
      await tester.pumpAndSettle();
      final febGrid = tester.getSize(find.byType(GridView).first);

      // September 2026: 30 days starting Tuesday = 5 rows
      await tester.pumpWidget(_dialogFor(svc, DateTime(2026, 9)));
      await tester.pumpAndSettle();
      final sepGrid = tester.getSize(find.byType(GridView).first);

      expect(febGrid.height, equals(sepGrid.height),
          reason:
              'Grid height must be fixed (6 rows) regardless of month row count');
    });

    testWidgets('grid renders day numbers for current month',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final svc = await _makeSvc();

      await tester.pumpWidget(_dialogFor(svc, DateTime(2026, 2)));
      await tester.pumpAndSettle();

      // February has days 1-28
      expect(find.text('1'), findsWidgets);
      expect(find.text('28'), findsWidgets);
    });
  });

  group('Month/year jump picker', () {
    testWidgets('tapping month/year header shows month grid', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final svc = await _makeSvc();
      await tester.pumpWidget(_dialogFor(svc, DateTime(2026, 2)));
      await tester.pumpAndSettle();

      // Tap the month name (FEBRUARY) to open picker
      await tester.tap(find.text('FEBRUARY'));
      await tester.pumpAndSettle();

      // Should show month abbreviations in 3x4 grid
      expect(find.text('JAN'), findsOneWidget);
      expect(find.text('FEB'), findsOneWidget);
      expect(find.text('DEC'), findsOneWidget);
    });
  });

  group('Preset chips', () {
    testWidgets('preset chips are visible in the dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final svc = await _makeSvc();
      await tester.pumpWidget(_dialogFor(svc, DateTime(2026, 2)));
      await tester.pumpAndSettle();

      expect(find.text('THIS MONTH'), findsOneWidget);
      expect(find.text('THIS YEAR'), findsOneWidget);
    });

    testWidgets('preset chip row is wrapped in ShaderMask for scroll hint',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final svc = StorageService(prefs);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RetroDateRangePickerDialog(storageService: svc),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ShaderMask), findsAtLeastNWidgets(1));
    });
  });

  group('DateRangePresets', () {
    test('thisMonth() returns first to last day of current month', () {
      final range = DateRangePresets.thisMonth();
      final now = DateTime.now();
      expect(range.start, equals(DateTime(now.year, now.month, 1)));
      expect(range.end.month, equals(now.month));
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      expect(range.end.day, equals(lastDay));
    });

    test('lastMonth() returns first to last day of previous month', () {
      final range = DateRangePresets.lastMonth();
      final now = DateTime.now();
      final expectedMonth = now.month == 1 ? 12 : now.month - 1;
      expect(range.start.month, equals(expectedMonth));
      expect(range.end.month, equals(expectedMonth));
    });

    test('thisYear() spans Jan 1 to Dec 31 of current year', () {
      final range = DateRangePresets.thisYear();
      final year = DateTime.now().year;
      expect(range.start, equals(DateTime(year, 1, 1)));
      expect(range.end, equals(DateTime(year, 12, 31)));
    });

    test('lastYear() spans Jan 1 to Dec 31 of previous year', () {
      final range = DateRangePresets.lastYear();
      final year = DateTime.now().year - 1;
      expect(range.start, equals(DateTime(year, 1, 1)));
      expect(range.end, equals(DateTime(year, 12, 31)));
    });

    test('allTime() returns a range ending today', () async {
      final svc = await _makeSvc();
      final range = DateRangePresets.allTime(svc);
      final today = DateTime.now();
      expect(range.end.year, equals(today.year));
      expect(range.end.month, equals(today.month));
      expect(range.end.day, equals(today.day));
    });

    test('lastWeek returns Mon-Sun of previous week', () {
      final range = DateRangePresets.lastWeek();
      // Start should be a Monday
      expect(range.start.weekday, DateTime.monday);
      // End should be a Sunday
      expect(range.end.weekday, DateTime.sunday);
      // End should be before this week's Monday
      final now = DateTime.now();
      final thisMonday = now.subtract(Duration(days: now.weekday - 1));
      final thisStart = DateTime(thisMonday.year, thisMonday.month, thisMonday.day);
      expect(range.end.isBefore(thisStart), isTrue);
      // Range should be exactly 7 days (Mon to Sun = 6 day difference)
      expect(range.end.difference(range.start).inDays, 6);
    });
  });

  group('Thumbnail rendering (no dart:io)', () {
    testWidgets('dialog renders without dart:io errors',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final svc = await _makeSvc();

      // Pump the dialog for January 2026. This exercises _buildDayCell for
      // every day in the month. The fix replaced File/existsSync/FileImage with
      // ThumbnailImage — no dart:io is imported, so this must not throw.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
        home: Scaffold(
          body: RetroDateRangePickerDialog(
            storageService: svc,
            initialRange: DateTimeRange(
              start: DateTime(2026, 1, 1),
              end: DateTime(2026, 1, 31),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Dialog renders correctly; no FileImage or dart:io in the widget tree.
      expect(find.byType(RetroDateRangePickerDialog), findsOneWidget);
      // ThumbnailImage is available as a widget type (import verified at
      // compile time); zero instances are expected since no clips are loaded.
      expect(find.byType(ThumbnailImage), findsNothing);
    });
  });
}
