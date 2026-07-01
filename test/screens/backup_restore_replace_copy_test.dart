import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/backup_restore_screen.dart';

/// The replace-mode confirmation must be EXACTLY true. A restore never
/// deletes clip files (backup_service.dart documents this: UUID names
/// don't collide, so the old metadata simply re-adopts them) — only the
/// journal index and settings are replaced, and clips absent from the
/// backup merely stop appearing in the app. Copy that says "replace ALL
/// data / ALL current clips" claims a wholesale deletion that never
/// happens.
void main() {
  Future<void> pumpReplaceDialog(WidgetTester tester,
      {bool archiveHasSettings = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (ctx) => BackupRestoreScreen.buildReplaceConfirmDialog(
                  ctx, archiveHasSettings: archiveHasSettings),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('replace confirmation states what is actually replaced '
      'and that video files stay on the device', (tester) async {
    await pumpReplaceDialog(tester);

    // What really changes: the journal index and settings.
    expect(find.textContaining('journal index and settings'), findsOneWidget);
    // Files are never deleted by a restore.
    expect(find.textContaining('stay on your device'), findsOneWidget);
    // Clips missing from the backup disappear from the app's view only.
    expect(find.textContaining('no longer appear'), findsOneWidget);
    // The safety net is still stated.
    expect(find.textContaining('roll back'), findsOneWidget);
  });

  testWidgets('replace confirmation no longer claims wholesale deletion',
      (tester) async {
    await pumpReplaceDialog(tester);

    expect(find.text('REPLACE ALL DATA?'), findsNothing);
    expect(find.textContaining('replace ALL current clips'), findsNothing);
  });

  testWidgets(
      'for a legacy v1 archive (no settings.json) the confirmation does '
      'NOT promise settings replacement — current settings stay',
      (tester) async {
    await pumpReplaceDialog(tester, archiveHasSettings: false);

    // The v2 copy's promise would be a lie here: v1 archives carry no
    // settings, so nothing replaces them.
    expect(find.textContaining('journal index and settings will be replaced'),
        findsNothing);
    expect(find.textContaining('contains no settings'), findsOneWidget);
    expect(find.textContaining('current settings stay'), findsOneWidget);
    // The rest of the honest copy still holds.
    expect(find.textContaining('stay on your device'), findsOneWidget);
    expect(find.textContaining('roll back'), findsOneWidget);
  });

  testWidgets('replace confirmation pops true on confirm, false on cancel',
      (tester) async {
    await pumpReplaceDialog(tester);
    await tester.tap(find.text(BackupRestoreScreen.replaceAllConfirmLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await pumpReplaceDialog(tester);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
