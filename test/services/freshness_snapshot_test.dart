// BACKUP_RETENTION_SPEC trigger 3, in PT's plaintext idiom: a silent
// freshness snapshot — when the newest vault snapshot is older than 7 days
// (or the vault is empty), the app quietly snapshots the current metadata
// + allowlisted settings post-first-frame. No nag, no badge — it just
// happens. And it must NEVER throw to the UI: freshness is a background
// kindness, not a surfaced error.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

/// A vault store whose every operation fails — disk full / quota / no dir.
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
  late StorageService storage;
  late SharedPreferences prefs;
  late InMemoryVaultStore vaultStore;

  BackupVault vault([VaultStore? store]) => BackupVault(
        store ?? vaultStore,
        appId: 'punctum',
        extension: 'json',
      );

  BackupService service({VaultStore? store}) => BackupService(
        storage,
        vault: vault(store),
        prefs: prefs,
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pt_freshness_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({'theme_mode': 1});
    prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
    vaultStore = InMemoryVaultStore();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  final liveMeta = {
    'clips': {
      '2026-07-01': [
        {'id': 'c1', 'filePath': 'clips/c1.mp4'}
      ]
    },
  };

  Future<void> writeMetadata(Map<String, dynamic> data) =>
      File('${tmp.path}/metadata.json').writeAsString(jsonEncode(data));

  test('an EMPTY vault gets a freshness snapshot of the live state',
      () async {
    await writeMetadata(liveMeta);

    final took = await service().maybeFreshnessSnapshot();

    expect(took, isTrue);
    final entries = await vault().list();
    expect(entries, hasLength(1));
    expect(entries.single.label, VaultLabel.freshness);
    final snapshot =
        jsonDecode(utf8.decode((await vault().read(entries.single.id))!))
            as Map<String, dynamic>;
    // Snapshots are BackupEnvelope-wrapped (C2-backup): the composite
    // lives under `payload`.
    final payload = snapshot['payload'] as Map<String, dynamic>;
    expect(payload['metadata'], liveMeta,
        reason: 'the freshness snapshot must be a real rollback point');
    expect(payload['settings']['theme_mode'], 1,
        reason: 'same envelope shape as the pre-restore snapshot — '
            'settings are part of what a rollback must cover');
  });

  test('a FRESH vault (recent snapshot) takes nothing', () async {
    await writeMetadata(liveMeta);
    final svc = service();
    await svc.maybeFreshnessSnapshot(); // seeds a just-now snapshot

    final tookAgain = await svc.maybeFreshnessSnapshot();

    expect(tookAgain, isFalse,
        reason: 'a snapshot newer than 7 days means no work to do');
    expect(await vault().list(), hasLength(1),
        reason: 'no duplicate snapshot may appear');
  });

  test('a STALE vault (newest snapshot >7 days old) snapshots again',
      () async {
    await writeMetadata(liveMeta);
    // Plant an old snapshot directly in the store.
    await vaultStore.put(
      VaultEntry(
        id: 'punctum-backup-old.json',
        createdAt:
            DateTime.now().toUtc().subtract(const Duration(days: 8)),
        sizeBytes: 2,
        label: VaultLabel.freshness,
        pinned: false,
        autoPinned: false,
      ),
      Uint8List.fromList(utf8.encode('{}')),
    );

    final took = await service().maybeFreshnessSnapshot();

    expect(took, isTrue);
    expect(await vault().list(), hasLength(2));
  });

  test('NEVER throws to the UI: a dead vault store just returns false',
      () async {
    await writeMetadata(liveMeta);
    final took = await service(store: _FailingVaultStore())
        .maybeFreshnessSnapshot();
    expect(took, isFalse);
  });
}
