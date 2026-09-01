// The primary-action sweep (fleet C5-primaryScreens, 360dp x 1.3 with the
// screen's one job reachable, then 320dp x 3.0 with nothing overflowing).
//
// This extends PT's own text-scale harness (test/visual, and the audit's
// screen harness it grew into) from widgets to whole screens, in the real
// Hearth theme a fresh install opens in, light and dark. The capture sheet
// is opened inside the sweep, because a closed sheet is unswept surface:
// that is where "Import from Galler" was clipped at 1.3.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';
import 'package:one_second_a_day/screens/calendar_screen.dart';
import 'package:one_second_a_day/screens/compilation_screen.dart';
import 'package:one_second_a_day/screens/day_view_screen.dart';
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

  Future<void> pump(WidgetTester tester, Widget home, Brightness b) =>
      tester.pumpWidget(MaterialApp(
        theme: AppTheme.buildTheme(b, Colors.green),
        home: home,
      ));

  /// Every label on screen must be drawn in full: a clipped Text does not
  /// throw, so the overflow sweep alone would miss it.
  void expectNoClippedText(WidgetTester tester) {
    final width = tester.view.physicalSize.width;
    for (final e in find.byType(RichText).evaluate()) {
      final p = e.renderObject! as RenderParagraph;
      if (!p.attached || !p.hasSize) continue;
      final text = p.text.toPlainText();
      expect(p.didExceedMaxLines, isFalse, reason: '"$text" was cut');
      // As drawn: through any transform (the wordmark scales down to fit).
      final r = MatrixUtils.transformRect(
          p.getTransformTo(null), Offset.zero & p.size);
      if (r.width == 0) continue;
      expect(r.right, lessThanOrEqualTo(width + 0.5),
          reason: '"$text" runs off the screen');
    }
  }

  for (final b in Brightness.values) {
    testWidgets('Calendar: CAPTURE, and the capture sheet (${b.name})',
        (tester) async {
      await runPrimaryActionSweep(
        tester,
        pumpScreen: () => pump(
            tester,
            CalendarScreen(
                storageService: storage, onThemeChanged: (_, __) {}),
            b),
        primaryAction: find.text('CAPTURE'),
        interact: () async {
          await tester.tap(find.text('CAPTURE'));
          await tester.pumpAndSettle();
          for (final label in [
            'Record Video',
            'Take Photo',
            'Import from Gallery',
          ]) {
            expect(find.text(label), findsOneWidget, reason: label);
          }
          // Running text a person reads is sentence case (mind-in-mind-08).
          expect(find.textContaining('Capture for '), findsOneWidget);
          expectNoClippedText(tester);
          Navigator.of(tester.element(find.text('Record Video'))).pop();
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('Compile: COMPILE (${b.name})', (tester) async {
      await runPrimaryActionSweep(
        tester,
        pumpScreen: () =>
            pump(tester, CompilationScreen(storageService: storage), b),
        primaryAction: find.text('COMPILE'),
      );
    });

    testWidgets('Day View, a day with no clip: CAPTURE (${b.name})',
        (tester) async {
      await runPrimaryActionSweep(
        tester,
        pumpScreen: () => pump(
            tester,
            DayViewScreen(
              storageService: storage,
              initialDate: DateTime(2026, 5, 14),
              onDelete: () {},
            ),
            b),
        primaryAction: find.textContaining('CAPTURE'),
        // Day View has its own copy of the capture sheet; sweep it open.
        interact: () async {
          await tester.tap(find.textContaining('CAPTURE').first);
          await tester.pumpAndSettle();
          expect(find.text('Import from Gallery'), findsOneWidget);
          expectNoClippedText(tester);
          Navigator.of(tester.element(find.text('Import from Gallery'))).pop();
          await tester.pumpAndSettle();
        },
      );
    });
  }
}
