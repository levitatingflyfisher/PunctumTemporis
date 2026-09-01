// The backup is a plain ZIP by design (AGENTS: user-held media, not an
// encrypted container), and the screen never said so while handing it to
// a Share sheet (lens audit writing-is-designing-03, finding 11; persona
// G5). One true sentence, above the button, before the decision: what the
// file holds and that anyone with it can open it.
//
// Each claim is checked against what BackupService.createBackup writes:
// clips/ and thumbnails/, metadata.json (dates, tags, place names and
// coordinates, names from face recognition), faces/ (the named face
// crops), settings.json, and compilations/ when montages are included.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/backup_restore_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the notice names what is in the file and that it is not locked', () {
    const n = BackupRestoreScreen.zipContentsNotice;
    for (final claim in [
      'isn’t password-protected',
      'clips',
      'dates',
      'places',
      'tags',
      'names and face pictures',
    ]) {
      expect(n, contains(claim), reason: claim);
    }
  });

  testWidgets('it is on the screen, above Create Backup', (tester) async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({'crt_effects': false});
    final svc = StorageService(await SharedPreferences.getInstance());
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: BackupRestoreScreen(storageService: svc),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final notice = find.text(BackupRestoreScreen.zipContentsNotice);
    expect(notice, findsOneWidget);
    expect(tester.getTopLeft(notice).dy,
        lessThan(tester.getTopLeft(find.text('CREATE BACKUP')).dy));
  });
}
