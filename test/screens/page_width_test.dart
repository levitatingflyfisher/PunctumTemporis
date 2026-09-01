// On a tablet or a desktop browser the phone layout must not stretch edge to
// edge, and the bars should not be boxed either. Before: main.dart's builder
// put the WHOLE app, bars included, in a 760px box. Now each top-level
// screen's body is an OhPage (640dp, centred) and the app bars span the
// window. Every piece of text inside a screen's OhPage must sit inside the
// centred column.
//
// Exempt, full-bleed on purpose: the camera screens and a clip playing on
// its own (the picture is the content), and the gallery/music pickers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/backup_restore_screen.dart';
import 'package:one_second_a_day/screens/calendar_screen.dart';
import 'package:one_second_a_day/screens/compilation_screen.dart';
import 'package:one_second_a_day/screens/day_view_screen.dart';
import 'package:one_second_a_day/screens/onboarding_screen.dart';
import 'package:one_second_a_day/screens/settings_screen.dart';
import 'package:one_second_a_day/screens/year_review_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wide = Size(1024, 900);
const _cap = OhPage.phoneMaxWidth;

void main() {
  late StorageService storage;

  setUp(() async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({'crt_effects': false});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  final screens = <String, Widget Function()>{
    'Calendar': () =>
        CalendarScreen(storageService: storage, onThemeChanged: (_, __) {}),
    'Settings': () =>
        SettingsScreen(storageService: storage, onThemeChanged: (_, __) {}),
    'Compile': () => CompilationScreen(storageService: storage),
    'Year in Review': () => YearReviewScreen(storageService: storage),
    'Backup & Restore': () => BackupRestoreScreen(storageService: storage),
    'Day View': () => DayViewScreen(
        storageService: storage,
        initialDate: DateTime(2026, 5, 14),
        onDelete: () {}),
    'Onboarding': () =>
        OnboardingScreen(storageService: storage, onComplete: () {}),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key}: content capped at ${_cap.toInt()}dp and centred',
        (tester) async {
      tester.view.physicalSize = _wide;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.buildTheme(Brightness.light, Colors.green),
        home: entry.value(),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final page = find.byType(OhPage);
      expect(page, findsWidgets, reason: 'the body is not an OhPage');
      final left = (_wide.width - _cap) / 2;
      final texts =
          find.descendant(of: page.first, matching: find.byType(Text));
      expect(texts, findsWidgets);
      for (final e in texts.evaluate()) {
        final box = e.renderObject! as RenderBox;
        if (!box.hasSize || !box.attached) continue;
        final r = box.localToGlobal(Offset.zero) & box.size;
        if (r.right <= 0 || r.left >= _wide.width) continue; // off-page
        // Inside a horizontal scroller (the Year in Review heatmap) text
        // runs past the viewport by design and is clipped to it.
        final inHorizontalScroll = find
            .ancestor(
                of: find.byWidget(e.widget),
                matching: find.byWidgetPredicate((w) =>
                    w is SingleChildScrollView &&
                    w.scrollDirection == Axis.horizontal))
            .evaluate()
            .isNotEmpty;
        if (inHorizontalScroll) continue;
        expect(r.left, greaterThanOrEqualTo(left - 0.5),
            reason: '"${(e.widget as Text).data}" starts outside the column');
        expect(r.right, lessThanOrEqualTo(left + _cap + 0.5),
            reason: '"${(e.widget as Text).data}" ends outside the column');
      }
    });
  }
}
