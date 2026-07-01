// Startup wiring for BACKUP_RETENTION_SPEC trigger 3: the app takes a
// silent freshness snapshot post-first-frame — no nag, no badge, and a
// vault failure must never reach the UI as an error.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/main.dart';
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

/// A vault store whose every operation fails.
class _FailingVaultStore implements VaultStore {
  @override
  Future<List<VaultEntry>> list() async => throw StateError('disk gone');
  @override
  Future<void> put(VaultEntry entry, Uint8List bytes) async =>
      throw StateError('disk full');
  @override
  Future<void> update(VaultEntry entry) async => throw StateError('no');
  @override
  Future<Uint8List?> read(String id) async => null;
  @override
  Future<void> delete(String id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late SharedPreferences prefs;
  late StorageService storage;
  late InMemoryVaultStore vaultStore;

  BackupVault vault([VaultStore? store]) => BackupVault(
        store ?? vaultStore,
        appId: 'punctum',
        extension: 'json',
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pt_startup_fresh_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({'theme_mode': 1});
    prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
    vaultStore = InMemoryVaultStore();
    await File('${tmp.path}/metadata.json').writeAsString(jsonEncode({
      'clips': {
        '2026-07-01': [
          {'id': 'c1', 'filePath': 'clips/c1.mp4'}
        ]
      },
    }));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  testWidgets(
      'post-first-frame the app silently takes a freshness snapshot '
      'when the vault is empty', (tester) async {
    // runAsync: the hook does real file I/O, which needs a real event loop.
    final entries = await tester.runAsync(() async {
      await tester.pumpWidget(OneSecondApp(
        storageService: storage,
        backupServiceFactory: () =>
            BackupService(storage, vault: vault(), prefs: prefs),
      ));
      await tester.pump();
      // The hook is fire-and-forget; drain the async work.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return vault().list();
    });
    expect(entries, hasLength(1));
    expect(entries!.single.label, VaultLabel.freshness);
  });

  testWidgets('a recent snapshot means the hook takes nothing new',
      (tester) async {
    final entries = await tester.runAsync(() async {
      await BackupService(storage, vault: vault(), prefs: prefs)
          .maybeFreshnessSnapshot();

      await tester.pumpWidget(OneSecondApp(
        storageService: storage,
        backupServiceFactory: () =>
            BackupService(storage, vault: vault(), prefs: prefs),
      ));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return vault().list();
    });
    expect(entries, hasLength(1),
        reason: 'fresh vault: startup must not stack duplicate snapshots');
  });

  testWidgets('a dead vault store never surfaces an error to the UI',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(OneSecondApp(
        storageService: storage,
        backupServiceFactory: () => BackupService(storage,
            vault: vault(_FailingVaultStore()), prefs: prefs),
      ));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(tester.takeException(), isNull,
        reason: 'freshness is best-effort — no crash, no error UI');
  });
}
