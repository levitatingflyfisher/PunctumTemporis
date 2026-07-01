// The "Include montage videos" toggle on the backup screen: ON by default
// (montages are the point of the app), persisted, and honored end-to-end —
// flipping it off must actually keep montage MP4s out of the created ZIP,
// not just flip a switch.
//
// Widget-test discipline: real filesystem work (seeding, and taps that
// drive the zip encode) runs inside tester.runAsync — real I/O never
// completes under the fake async zone and hangs pumpAndSettle.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/screens/backup_restore_screen.dart';
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
    tmp = Directory.systemTemp.createTempSync('pt_toggle_');
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

  Future<void> seed(WidgetTester tester, {bool withMontage = false}) async {
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      svc = StorageService(prefs);
      await svc.initialize();
      if (withMontage) {
        final path = '${tmp.path}/compiled/jul.mp4';
        await File(path).parent.create(recursive: true);
        await File(path).writeAsBytes(List<int>.filled(64, 7));
        await svc.addCompilation(Compilation(
          id: 'jul',
          title: 'jul',
          filePath: path,
          clipIds: const [],
          createdAt: DateTime(2026, 7, 1),
        ));
      }
    });
  }

  Future<Archive> createBackupViaUi(WidgetTester tester) async {
    await tester.pumpWidget(wrap(BackupRestoreScreen(storageService: svc)));
    await tester.pumpAndSettle();

    late Archive archive;
    await tester.runAsync(() async {
      await tester.tap(find.text('CREATE BACKUP'));
      // The zip encode + verify-by-read-back is real I/O; give it room.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final zips = tmp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('onesecond_backup_'))
          .toList();
      expect(zips, hasLength(1), reason: 'the backup ZIP must exist');
      archive = ZipDecoder().decodeBytes(await zips.first.readAsBytes());
    });
    await tester.pumpAndSettle();
    return archive;
  }

  group('StorageService include-montages pref', () {
    test('defaults to true and persists a change', () async {
      final prefs = await SharedPreferences.getInstance();
      svc = StorageService(prefs);
      expect(svc.getIncludeMontagesInBackup(), isTrue,
          reason: 'montages are the point — carrying them is the default');
      await svc.setIncludeMontagesInBackup(false);
      expect(svc.getIncludeMontagesInBackup(), isFalse);
    });
  });

  group('backup screen toggle', () {
    testWidgets('renders ON by default and persists when flipped',
        (tester) async {
      await seed(tester);
      await tester.pumpWidget(wrap(BackupRestoreScreen(storageService: svc)));
      await tester.pumpAndSettle();

      expect(find.text('Include montage videos'), findsOneWidget);
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(svc.getIncludeMontagesInBackup(), isFalse);
    });

    testWidgets('toggle OFF keeps montage files out of the created ZIP',
        (tester) async {
      await seed(tester, withMontage: true);
      await tester.runAsync(() => svc.setIncludeMontagesInBackup(false));

      final archive = await createBackupViaUi(tester);
      expect(
          archive
              .map((e) => e.name)
              .where((n) => n.startsWith('compilations/')),
          isEmpty,
          reason: 'the flipped-off toggle must reach createBackup');
    });

    testWidgets('toggle ON (default) carries montage files in the ZIP',
        (tester) async {
      await seed(tester, withMontage: true);

      final archive = await createBackupViaUi(tester);
      expect(archive.map((e) => e.name), contains('compilations/jul.mp4'));
    });
  });
}
