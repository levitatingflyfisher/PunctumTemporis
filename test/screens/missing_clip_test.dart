// A day whose clip file is gone (lens audit humane-interface-04, persona G3).
//
// Before: `_initializePlayer` found the file missing, flashed a red
// "Video file not found" SnackBar for four seconds and left an
// indeterminate spinner in the video area forever, for a state it had
// already established. Now the missing file is a terminal state: no
// spinner, and in the place the video would play, a sentence saying the
// clip isn't on this device with the actions that help.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/screens/clip_preview_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;
  late Clip clip;

  setUp(() async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({'crt_effects': false});
    storage = StorageService(await SharedPreferences.getInstance());
    clip = Clip(
      id: 'gone',
      date: '2026-09-04',
      filePath: 'nonexistent/gone.mp4',
      type: ClipType.video,
      createdAt: DateTime(2026, 9, 4),
      tags: const ['family'],
    );
    storage.setClipsForTest({
      '2026-09-04': [clip],
    });
  });

  Future<void> pumpPreview(WidgetTester tester, {bool embedded = false}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: embedded
          ? Scaffold(
              body: ClipPreviewScreen(
                  storageService: storage, clip: clip, embedded: true))
          : ClipPreviewScreen(storageService: storage, clip: clip),
    ));
    // The existence check is real file I/O; give it a real-clock beat.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final embedded in [false, true]) {
    final where = embedded ? 'embedded in Day View' : 'on its own';

    testWidgets('a missing file stops the spinner ($where)', (tester) async {
      await pumpPreview(tester, embedded: embedded);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a missing file says so in place, with a way on ($where)',
        (tester) async {
      await pumpPreview(tester, embedded: embedded);
      expect(find.text(ClipPreviewScreen.missingClipTitle), findsOneWidget);
      expect(find.text(ClipPreviewScreen.missingClipMessage), findsOneWidget);
      expect(find.text('Remove this entry'), findsOneWidget);
      // No transient red banner doing the panel's job.
      expect(find.byType(SnackBar), findsNothing);
    });
  }

  for (final embedded in [false, true]) {
    final where = embedded ? 'embedded in Day View' : 'on its own';
    testWidgets('a missing file offers no Share or Trim ($where)',
        (tester) async {
      await pumpPreview(tester, embedded: embedded);
      // There is no file to share or cut; Delete (Remove) stays.
      expect(find.byTooltip('Share clip'), findsNothing);
      expect(find.text('Share'), findsNothing);
      expect(find.text('TRIM'), findsNothing);
      expect(find.byIcon(Icons.content_cut), findsNothing);
      expect(find.byTooltip('Delete clip'), findsOneWidget);
    });
  }

  testWidgets('the day is still drawn around the missing video',
      (tester) async {
    await pumpPreview(tester);
    expect(find.text('family'), findsWidgets);
  });
}
