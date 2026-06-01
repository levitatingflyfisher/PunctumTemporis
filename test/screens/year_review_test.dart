import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/screens/year_review_screen.dart';

void main() {
  late StorageService storageService;

  setUp(() async {
    AppTheme.visualStyle = 'modern';
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'crt_effects': false,
    });
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  Widget buildApp() {
    return MaterialApp(
      theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
      home: YearReviewScreen(storageService: storageService),
    );
  }

  testWidgets('renders without overflow on empty data', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.byType(YearReviewScreen), findsOneWidget);
    expect(find.text('YEAR IN REVIEW'), findsOneWidget);
  });

  testWidgets('shows empty state when no clips', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    // Scroll down to find the empty state message
    await tester.scrollUntilVisible(
      find.textContaining('NO CLIPS FOR'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final year = DateTime.now().year;
    expect(find.textContaining('NO CLIPS FOR $year'), findsOneWidget);
  });

  testWidgets('shows year selector with current year', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    final year = DateTime.now().year;
    expect(find.text(year.toString()), findsOneWidget);
  });

  testWidgets('section headers render correctly', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.text('ACTIVITY'), findsOneWidget);
    expect(find.text('MONTHLY'), findsOneWidget);
    expect(find.text('STATISTICS'), findsOneWidget);
  });

  group('StorageService range-stats', () {
    test('uniqueDatesInRange returns correct set', () {
      final result =
          storageService.uniqueDatesInRange('2026-01-01', '2026-12-31');
      expect(result, isEmpty);
    });

    test('getStreakInRange returns 0 for empty', () {
      final result =
          storageService.getStreakInRange('2026-01-01', '2026-12-31');
      expect(result, 0);
    });

    test('getLocationCountsInRange returns empty for no clips', () {
      final result =
          storageService.getLocationCountsInRange('2026-01-01', '2026-12-31');
      expect(result, isEmpty);
    });

    test('getTagCountsInRange returns empty for no clips', () {
      final result =
          storageService.getTagCountsInRange('2026-01-01', '2026-12-31');
      expect(result, isEmpty);
    });

    test('getFaceCountsInRange returns empty for no clips', () {
      final result =
          storageService.getFaceCountsInRange('2026-01-01', '2026-12-31');
      expect(result, isEmpty);
    });
  });

  group('Reminder preferences', () {
    test('default reminder is disabled', () {
      expect(storageService.getReminderEnabled(), false);
    });

    test('default reminder time is 20:00', () {
      final time = storageService.getReminderTime();
      expect(time.hour, 20);
      expect(time.minute, 0);
    });

    test('setReminderEnabled persists', () async {
      await storageService.setReminderEnabled(true);
      expect(storageService.getReminderEnabled(), true);
    });

    test('setReminderTime persists', () async {
      await storageService
          .setReminderTime(const TimeOfDay(hour: 9, minute: 30));
      final time = storageService.getReminderTime();
      expect(time.hour, 9);
      expect(time.minute, 30);
    });
  });
}
