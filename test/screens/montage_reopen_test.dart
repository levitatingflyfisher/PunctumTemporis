// Re-opening a saved montage must be a faithful, calm experience:
//   * the montage recipe (clip-audio level + music segments) saved on the
//     row seeds the screen, so COMPILE reproduces the montage instead of
//     falling back to defaults,
//   * a row whose video file isn't on this device (migrated from a previous
//     install) shows a quiet inline notice pointing at the gallery copy and
//     the rebuild path — never a raw PlatformException snackbar.
//
// Widget-test discipline: everything that touches the real filesystem
// (storage init, adding rows, and taps that make the screen stat files)
// runs inside tester.runAsync — real I/O never completes under the fake
// async zone and hangs pumpAndSettle.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/screens/compilation_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';

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
  late StorageService svc;

  setUp(() {
    AppTheme.visualStyle = 'retro';
    tmp = Directory.systemTemp.createTempSync('pt_reopen_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
        home: child,
      );

  Compilation montage({double? originalVolume, List<AudioSegment>? segments}) =>
      Compilation(
        id: 'm1',
        title: 'Jul 1 - Jul 31, 2026',
        filePath: '${tmp.path}/compiled/gone.mp4', // never written
        clipIds: const [],
        createdAt: DateTime(2026, 8, 1),
        startDate: '2026-07-01',
        endDate: '2026-07-31',
        originalVolume: originalVolume,
        audioSegments: segments,
      );

  Future<void> seed(WidgetTester tester, Compilation comp) async {
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      svc = StorageService(prefs);
      await svc.initialize();
      await svc.addCompilation(comp);
    });
  }

  Future<void> openTile(WidgetTester tester) async {
    await tester.pumpWidget(wrap(CompilationScreen(storageService: svc)));
    await tester.pumpAndSettle();
    // The tap makes the screen stat the montage file — real I/O.
    await tester.runAsync(() async {
      await tester.tap(find.text('Jul 1 - Jul 31, 2026'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  group('buildCompilationRecord', () {
    test('carries the montage recipe alongside the basics', () {
      final clips = [
        Clip(
          id: 'c1',
          date: '2026-07-01',
          filePath: '/clips/c1.mp4',
          type: ClipType.video,
          createdAt: DateTime(2026, 7, 1),
          duration: 1.5,
        ),
      ];
      final record = CompilationScreen.buildCompilationRecord(
        id: 'comp1',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 31),
        outputPath: '/compiled/jul.mp4',
        clips: clips,
        originalVolume: 0.45,
        audioSegments: [
          AudioSegment(
              filePath: '/music/song.mp3', fileName: 'song.mp3', volume: 0.7),
        ],
      );
      expect(record.originalVolume, 0.45);
      expect(record.audioSegments, hasLength(1));
      expect(record.audioSegments!.first.fileName, 'song.mp3');
      expect(record.filePath, '/compiled/jul.mp4');
      expect(record.clipIds, ['c1']);
      expect(record.duration, 1.5);
      expect(record.startDate, '2026-07-01');
      expect(record.endDate, '2026-07-31');
    });
  });

  group('re-opening a montage', () {
    testWidgets('missing video shows the calm notice, not a snackbar',
        (tester) async {
      await seed(tester, montage());
      await openTile(tester);

      expect(find.text(CompilationScreen.missingMontageNotice), findsOneWidget,
          reason: 'a migrated row deserves an explanation and a path forward');
      expect(find.byType(SnackBar), findsNothing,
          reason: 'a missing file on a re-open is a state, not an error');
    });

    testWidgets('saved recipe seeds the audio controls', (tester) async {
      await seed(
        tester,
        montage(
          originalVolume: 0.45,
          segments: [
            AudioSegment(
                filePath: '/music/song.mp3',
                fileName: 'song.mp3',
                volume: 0.7),
          ],
        ),
      );
      // The audio controls live in the settings section, which renders only
      // when the range has clips — true for any montage restored with its
      // source material.
      await tester.runAsync(() => svc.addClip(Clip(
            id: 'c1',
            date: '2026-07-15',
            filePath: '${tmp.path}/clips/c1.mp4',
            type: ClipType.video,
            createdAt: DateTime(2026, 7, 15),
          )));
      await openTile(tester);

      // The ORIGINAL volume slider renders first and must carry the saved
      // level; the music segment card must show the saved track.
      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders, isNotEmpty,
          reason: 'a seeded recipe makes the audio section render');
      expect(sliders.first.value, closeTo(0.45, 0.001));
      expect(find.textContaining('song.mp3'), findsWidgets);
    });

    testWidgets('a legacy row without a recipe still opens quietly',
        (tester) async {
      await seed(tester, montage());
      await openTile(tester);

      expect(find.text(CompilationScreen.missingMontageNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
