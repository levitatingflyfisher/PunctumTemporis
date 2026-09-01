// The calendar's header (lens audit finding 2; dont-make-me-think-04,
// design-for-hackers-01; operator ruling on top bars: icon plus a short
// visible label, a tooltip is never a command's only name).
//
// Before: four bare glyphs (the gear had no tooltip at all) and a wordmark
// that ellipsized to "ONE ..." at 360dp. These tests hold the fix: every
// action carries a word, the theme is one control away, and the product's
// name is never cut, in every visual style, at 360dp x 1.3 (the persona
// E1 check) and at 320dp x 3.0 (the worst case the overflow test sweeps).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/calendar_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'crt_effects': false});
    storage = StorageService(await SharedPreferences.getInstance());
  });
  tearDown(() => AppTheme.visualStyle = 'hearth');

  Future<void> pumpAt(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: CalendarScreen(
          storageService: storage, onThemeChanged: (_, __) {}),
    ));
    await tester.pumpAndSettle();
  }

  for (final style in ['hearth', 'retro', 'modern']) {
    for (final (size, scale) in [
      (const Size(360, 800), 1.3),
      (const Size(320, 800), 3.0),
    ]) {
      final cell = '$style ${size.width.toInt()}dp x $scale';

      testWidgets('every header action has a visible word ($cell)',
          (tester) async {
        AppTheme.visualStyle = style;
        await pumpAt(tester, size, scale);
        for (final word in ['Filter', 'Year', 'Compile', 'Settings']) {
          final label = find.text(word);
          expect(label, findsOneWidget, reason: word);
          final box = tester.getRect(label);
          expect(box.right, lessThanOrEqualTo(size.width + 0.5),
              reason: '$word runs off the screen');
        }
        expect(find.byType(OhThemeToggle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the wordmark is never cut ($cell)', (tester) async {
        AppTheme.visualStyle = style;
        await pumpAt(tester, size, scale);
        final paragraph = tester.renderObject<RenderParagraph>(
            find.text(CalendarScreen.wordmark));
        expect(paragraph.didExceedMaxLines, isFalse);
        // Measured as drawn (after any scale-down), not as laid out.
        final drawn = tester.getRect(find.text(CalendarScreen.wordmark));
        expect(drawn.left, greaterThanOrEqualTo(0));
        expect(drawn.right, lessThanOrEqualTo(size.width + 0.5));
      });
    }
  }

  testWidgets('Settings is reachable by its word', (tester) async {
    await pumpAt(tester, const Size(360, 800), 1.0);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
  });
}
