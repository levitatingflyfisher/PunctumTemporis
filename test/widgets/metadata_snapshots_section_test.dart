import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/widgets/metadata_snapshots_section.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';

void main() {
  late InMemoryVaultStore store;
  BackupVault vault() =>
      BackupVault(store, appId: 'punctum', extension: 'json');

  setUp(() => store = InMemoryVaultStore());

  Widget harness({Future<void> Function(String)? onRestore}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MetadataSnapshotsSection(
              vault: vault(),
              onRestoreSnapshot: onRestore ?? (_) async {},
            ),
          ),
        ),
      );

  testWidgets('empty vault shows the calm empty line', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.textContaining('No snapshots yet'), findsOneWidget);
  });

  testWidgets('lists snapshots with label and age', (tester) async {
    await vault().save(Uint8List.fromList([1]), label: VaultLabel.preRestore);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Safety snapshot'), findsOneWidget);
    expect(find.text('made today'), findsOneWidget);
  });

  testWidgets(
      'restore asks first with the calm rollback copy, then hands the id '
      'to the owner', (tester) async {
    final entry = await vault()
        .save(Uint8List.fromList([1]), label: VaultLabel.preRestore);
    String? restored;
    await tester
        .pumpWidget(harness(onRestore: (id) async => restored = id));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_backup_restore));
    await tester.pumpAndSettle();
    expect(find.text('Restore this snapshot?'), findsOneWidget);
    expect(find.textContaining('Video files are not touched'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(restored, entry.id);
  });

  testWidgets('delete asks first, then removes the snapshot', (tester) async {
    final entry =
        await vault().save(Uint8List.fromList([1]), label: VaultLabel.manual);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete snapshot?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await store.read(entry.id), isNull);
    expect(find.textContaining('No snapshots yet'), findsOneWidget);
  });

  testWidgets('no overflow at 320 dp x 3.0 text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await vault().save(Uint8List.fromList([1]), label: VaultLabel.preRestore);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
      child: harness(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
