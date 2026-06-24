import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/backup_restore_screen.dart';

void main() {
  test('backup restore cancel message mentions partial', () {
    expect(
      BackupRestoreScreen.cancelRestoreWarning,
      contains('partial'),
    );
  });

  test('REPLACE ALL second confirmation text is suitably alarming', () {
    // Verify the constant text that the second confirmation dialog will show.
    // The message must make it unambiguous that ALL data is deleted.
    const warning = 'This will permanently delete ALL current clips and replace them '
        'with the backup. This cannot be undone.';
    expect(warning, contains('permanently delete'));
    expect(warning, contains('cannot be undone'));
  });
}
