import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/screens/day_view_screen.dart';
import 'package:one_second_a_day/models/clip.dart';

/// Accessibility-overflow regression test for [DayViewScreen]'s empty-day state.
///
/// The empty-day "CAPTURE" button is a horizontal Row (icon + label). At a
/// narrow width (320dp) with a large accessibility text scale (×3.0) that Row
/// overflowed with a `RenderFlex overflowed` error. Pumping the empty-day page
/// at that worst-case combination and asserting no exception guards the fix.
void main() {
  late StorageService storageService;

  setUp(() async {
    AppTheme.visualStyle = 'retro';
    addTearDown(() => AppTheme.visualStyle = 'hearth');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'crt_effects': false,
    });
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  testWidgets('DayViewScreen empty-day does not overflow at 320dp / scale 3.0',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 800);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(3.0)),
        child: child!,
      ),
      home: DayViewScreen(
        storageService: storageService,
        initialDate: DateTime(2026, 5, 14), // past date → capturable empty day
        onDelete: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // A day with a clip: the info chips under the video (type, duration,
  // place, TRIM) were a fixed Row that overflowed at 360dp x 1.3 with a
  // realistic place name (lens audit checklist-manifesto-03 / mind-in-mind-13,
  // found by the audit's screen harness). They wrap now.
  for (final style in ['hearth', 'retro']) {
    for (final (width, scale) in [(360.0, 1.3), (320.0, 3.0), (400.0, 1.0)]) {
      testWidgets(
          'a day with a clip does not overflow ($style, ${width.toInt()}dp '
          'x $scale)', (tester) async {
        AppTheme.visualStyle = style;
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);
        final day = DateTime(2026, 5, 14);
        storageService.setClipsForTest({
          '2026-05-14': [
            Clip(
              id: 'c1',
              date: '2026-05-14',
              filePath: 'nonexistent/c1.mp4',
              type: ClipType.imported,
              createdAt: day,
              duration: 1.0,
              tags: const ['family', 'backyard'],
              locationLabel: 'Brooklyn, NY',
            ),
          ],
        });

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: DayViewScreen(
            storageService: storageService,
            initialDate: day,
            onDelete: () {},
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('Brooklyn, NY'), findsOneWidget);
      });
    }
  }
}
