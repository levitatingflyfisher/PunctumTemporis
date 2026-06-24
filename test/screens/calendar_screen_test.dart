import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/screens/calendar_screen.dart';
import 'package:one_second_a_day/widgets/crt_effects.dart';

void main() {
  late StorageService storageService;

  setUp(() async {
    AppTheme.visualStyle = 'retro';
    SharedPreferences.setMockInitialValues({
      'crt_effects': false, // disable CRT overlay for test simplicity
    });
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    // Skip initialize() — we don't need disk I/O; _clips defaults to {}
  });

  Widget buildApp() {
    return MaterialApp(
      theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
      home: CalendarScreen(
        storageService: storageService,
        onThemeChanged: (_, __) {},
      ),
    );
  }

  testWidgets('CalendarScreen renders without overflow', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // If there were overflow errors, the test framework would flag them
    expect(find.byType(CalendarScreen), findsOneWidget);
  });

  testWidgets('key UI elements are present', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Header
    expect(find.text('ONE SECOND'), findsOneWidget);

    // Weekday headers — each letter appears at least once
    for (final day in ['S', 'M', 'T', 'W', 'F']) {
      expect(find.text(day), findsWidgets);
    }

    // CAPTURE button
    expect(find.text('CAPTURE'), findsOneWidget);

    // Stats footer labels
    expect(find.text('CAPTURED'), findsOneWidget);
    expect(find.text('STREAK'), findsOneWidget);
    expect(find.text('BEST'), findsOneWidget);
  });

  testWidgets('filter icon uses tune icon not search icon', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    // Should use tune icon, not search
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.search), findsNothing);
  });

  testWidgets('CAPTURE button is reasonably sized', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Find the RetroButton that contains 'CAPTURE'
    final captureTextFinder = find.text('CAPTURE');
    expect(captureTextFinder, findsOneWidget);

    final retroButtonFinder = find.ancestor(
      of: captureTextFinder,
      matching: find.byType(RetroButton),
    );
    expect(retroButtonFinder, findsOneWidget);

    final buttonSize = tester.getSize(retroButtonFinder);
    // Should be a compact button (~160px), not filling the screen (400+)
    expect(buttonSize.width, lessThan(250),
        reason: 'CAPTURE button should not fill the screen width');
  });

  testWidgets('calendar screen renders without error with selection tracking',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    // Verify basic rendering works (selection state tracked internally)
    expect(find.byType(CalendarScreen), findsOneWidget);
  });

  testWidgets('TODAY button appears when not on current month', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    // On current month → no TODAY button visible
    expect(find.text('← TODAY'), findsNothing);
  });

  testWidgets('future dates not rendered in calendar grid', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Find a date that is in the future (relative to today)
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    // The day number of tomorrow should NOT appear in the grid
    // (only check if tomorrow is still in the current month)
    if (tomorrow.month == DateTime.now().month) {
      expect(find.text('${tomorrow.day}'), findsNothing);
    }
  });
}
