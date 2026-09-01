// Deleting a clip (lens audit finding 6; persona G4; fleet delete ruling).
//
// Before: a two-equal-button "DELETE CLIP?" dialog with the raw
// YYYY-MM-DD date, no undo and no trash, guarding the one second of that
// day that will ever exist. The Delete button is a deliberate act, so under
// the ruling it does not ask: the clip leaves the day at once, and an Undo
// that never times out stays in the app-wide bar, surviving the preview
// screen closing. Undo puts the clip back and the day redraws.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/main.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/screens/clip_preview_screen.dart';
import 'package:one_second_a_day/screens/day_view_screen.dart';
import 'package:one_second_a_day/services/backup_service.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.base);
  final String base;
  @override
  Future<String?> getApplicationDocumentsPath() async => base;
  @override
  Future<String?> getApplicationSupportPath() async => base;
  @override
  Future<String?> getTemporaryPath() async => '$base/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late SharedPreferences prefs;
  late StorageService storage;
  final day = DateTime(2026, 9, 4);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pt_clip_delete_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'crt_effects': false,
    });
    prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
    await storage.initialize();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<Clip> addClip(WidgetTester tester, String id) async {
    // A path that does not exist keeps video_player out of the test; the
    // preview shows its missing-file state, and Delete is still there.
    final clip = Clip(
      id: id,
      date: '2026-09-04',
      filePath: '${tmp.path}/clips/$id-absent.mp4',
      type: ClipType.video,
      createdAt: day,
    );
    // Real file I/O needs a real event loop, which testWidgets' fake clock
    // does not turn: without runAsync this await never returns.
    await tester.runAsync(() => storage.addClip(clip));
    return clip;
  }

  Future<void> settle(WidgetTester tester) async {
    // Each real file operation (open, write, close) needs a turn of the
    // real event loop and then a pump to deliver its result; loop enough
    // times for a metadata write to finish and its route pop to animate.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> pumpAppOnDay(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(OneSecondApp(
      storageService: storage,
      backupServiceFactory: () => BackupService(storage,
          vault: BackupVault(InMemoryVaultStore(),
              appId: 'punctum', extension: 'json'),
          prefs: prefs),
    ));
    await settle(tester);
    tester.state<NavigatorState>(find.byType(Navigator).last).push(
          MaterialPageRoute<void>(
            builder: (_) => DayViewScreen(
              storageService: storage,
              initialDate: day,
              onDelete: () {},
            ),
          ),
        );
    await settle(tester);
  }

  testWidgets('Delete does not ask, and offers an Undo that stays',
      (tester) async {
    await addClip(tester, 'only');
    await pumpAppOnDay(tester);

    await tester.tap(find.byTooltip('Delete clip').first);
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(storage.hasClipForDate('2026-09-04'), isFalse);
    expect(find.text('Deleted the clip for Sep 4, 2026'), findsOneWidget);

    // No timer: long after any SnackBar would have gone, it is still there.
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('Undo puts the clip back and the day shows it again',
      (tester) async {
    await addClip(tester, 'only');
    await pumpAppOnDay(tester);

    await tester.tap(find.byTooltip('Delete clip').first);
    await settle(tester);
    await tester.tap(find.text('Undo'));
    await settle(tester);

    expect(storage.hasClipForDate('2026-09-04'), isTrue);
    expect(find.text('Undo'), findsNothing);
    // The day view redrew from storage: the clip's preview is back, not
    // the empty-day invitation.
    expect(find.byTooltip('Delete clip'), findsWidgets);
  });

  testWidgets(
      'deleting from a clip opened out of a multi-clip day lands back on '
      'that day, not the calendar', (tester) async {
    await addClip(tester, 'first');
    await addClip(tester, 'second');
    await pumpAppOnDay(tester);

    // Open the first clip from the day's list.
    await tester.tap(find.byType(InkWell).first);
    await settle(tester);
    await tester.tap(find.byTooltip('Delete clip').first);
    await settle(tester);

    expect(find.byType(DayViewScreen), findsOneWidget);
    // The preview closed; the day's remaining clip is what shows.
    expect(find.byType(ClipPreviewScreen), findsOneWidget,
        reason: 'one clip left: the day shows it embedded, full screen');
    expect(storage.getClipsForDate('2026-09-04'), hasLength(1));
  });
}
