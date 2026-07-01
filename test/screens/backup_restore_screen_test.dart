import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/backup_restore_screen.dart';

void main() {
  test('backup restore cancel message mentions partial', () {
    expect(
      BackupRestoreScreen.cancelRestoreWarning,
      contains('partial'),
    );
  });

  test(
      'replace-mode second confirmation is honest about the safety net '
      '(the old "cannot be undone" stopped being true when the mandatory '
      'pre-restore snapshot landed) — asserted on the REAL const, not a '
      'copy of it', () {
    expect(BackupRestoreScreen.replaceAllWarning, contains('roll back'));
    expect(
      BackupRestoreScreen.replaceAllWarning.contains('cannot be undone'),
      isFalse,
    );
  });
}
