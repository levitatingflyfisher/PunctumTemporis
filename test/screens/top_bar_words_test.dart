// Top-bar actions carry a visible word (fleet top-bar ruling: icon plus a
// short label; a tooltip is never a command's only name). C11 accepts a
// tooltip, so these hold the stricter ruling on PT's own bars, and sweep
// them at 360dp x 1.3 and 320dp x 3.0 so the words never push a bar off
// the screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/screens/clip_preview_screen.dart';
import 'package:one_second_a_day/screens/day_view_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;
  final clip = Clip(
    id: 'c1',
    date: '2026-09-04',
    filePath: 'nonexistent/c1.mp4',
    type: ClipType.video,
    createdAt: DateTime(2026, 9, 4),
  );

  setUp(() async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({'crt_effects': false});
    storage = StorageService(await SharedPreferences.getInstance());
    storage.setClipsForTest({
      '2026-09-04': [clip],
    });
  });

  Future<void> pumpAt(
      WidgetTester tester, Widget home, double width, double scale) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final (width, scale) in [(360.0, 1.3), (320.0, 3.0)]) {
    final cell = '${width.toInt()}dp x $scale';

    testWidgets('a clip opened on its own: Share and Delete are words ($cell)',
        (tester) async {
      await pumpAt(tester, ClipPreviewScreen(storageService: storage, clip: clip),
          width, scale);
      expect(tester.takeException(), isNull);
      for (final word in ['Share', 'Delete']) {
        expect(find.text(word), findsOneWidget, reason: word);
        expect(tester.getRect(find.text(word)).right,
            lessThanOrEqualTo(width + 0.5));
      }
    });

    testWidgets('Day View: Today is a word ($cell)', (tester) async {
      await pumpAt(
          tester,
          DayViewScreen(
              storageService: storage,
              initialDate: DateTime(2026, 9, 4),
              onDelete: () {}),
          width,
          scale);
      expect(tester.takeException(), isNull);
      expect(find.text('Today'), findsOneWidget);
    });
  }
}
