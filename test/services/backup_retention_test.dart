// BACKUP_RETENTION_SPEC adoption, in PT's own idiom: the plaintext ZIP
// backup keeps its identity, but gains the retention spine —
//   * a MANDATORY fail-closed metadata snapshot before every restore
//     (rollback is complete because restore never deletes clip files:
//     UUID names don't collide, so old clips stay on disk and the old
//     metadata.json re-adopts them),
//   * verify-by-read-back on create ("untested backups don't count"),
//   * settings included in the archive (the old silent gap),
//   * snapshot restore that itself takes a snapshot first.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

/// A vault store whose [put] always fails — disk full / quota.
class _FailingVaultStore implements VaultStore {
  @override
  Future<List<VaultEntry>> list() async => const [];
  @override
  Future<void> put(VaultEntry entry, Uint8List bytes) async =>
      throw StateError('disk full');
  @override
  Future<void> update(VaultEntry entry) async {}
  @override
  Future<Uint8List?> read(String id) async => null;
  @override
  Future<void> delete(String id) async {}
}

Uint8List _zipWithMetadata(Map<String, dynamic> metadata,
    {Map<String, dynamic>? settings}) {
  final archive = Archive();
  final metaBytes = utf8.encode(jsonEncode(metadata));
  archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));
  if (settings != null) {
    final s = utf8.encode(jsonEncode(settings));
    archive.addFile(ArchiveFile('settings.json', s.length, s));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
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
    tmp = await Directory.systemTemp.createTemp('pt_retention_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({
      'theme_mode': 1,
      'pinned_tags': <String>['birthday'],
      'clips_migrated_v2': true, // internal — must NEVER travel in a backup
    });
    prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
    vaultStore = InMemoryVaultStore();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> writeMetadata(Map<String, dynamic> data) => File(
          '${tmp.path}/metadata.json')
      .writeAsString(jsonEncode(data));

  Future<Map<String, dynamic>> readMetadata() async => jsonDecode(
          await File('${tmp.path}/metadata.json').readAsString())
      as Map<String, dynamic>;

  final backupMeta = {
    'clips': {
      '2026-07-01': [
        {
          'id': 'c-new',
          'filePath': 'clips/c-new.mp4',
          'thumbnailPath': 'thumbnails/c-new.jpg',
        }
      ],
    },
  };

  group('mandatory pre-restore snapshot (fail-closed)', () {
    test('restore vaults the CURRENT metadata first, then applies', () async {
      final current = {
        'clips': {
          '2026-01-01': [
            {'id': 'c-old', 'filePath': 'clips/c-old.mp4'}
          ]
        },
      };
      await writeMetadata(current);

      await service()
          .restoreBackup(_zipWithMetadata(backupMeta), (_) {}, replace: true);

      final entries = await vault().list();
      expect(entries, hasLength(1));
      expect(entries.single.label, VaultLabel.preRestore);
      expect(entries.single.id, endsWith('.json'));
      final snapshot =
          jsonDecode(utf8.decode((await vault().read(entries.single.id))!))
              as Map<String, dynamic>;
      // Snapshots are BackupEnvelope-wrapped (C2-backup): the composite
      // lives under `payload`.
      expect(snapshot['app'], 'punctumtemporis');
      final payload = snapshot['payload'] as Map<String, dynamic>;
      expect(payload['metadata'], current,
          reason: 'the rollback must hold exactly the pre-restore metadata');
      expect(payload['settings']['theme_mode'], 1,
          reason: 'REVIEW FIX: settings are part of the rollback too — '
              'replace-mode clobbers them, so the snapshot must cover them');
      expect(payload['settings'].containsKey('clips_migrated_v2'), isFalse,
          reason: 'internal keys never travel');

      final after = await readMetadata();
      expect((after['clips'] as Map).keys, contains('2026-07-01'));
    });

    test(
        'FAIL-CLOSED: when the snapshot cannot be saved, the restore is '
        'refused and metadata is untouched', () async {
      final current = {'clips': <String, Object?>{}, 'marker': 'untouched'};
      await writeMetadata(current);

      expect(
        () => service(store: _FailingVaultStore())
            .restoreBackup(_zipWithMetadata(backupMeta), (_) {}),
        throwsA(isA<PreRestoreSnapshotException>()),
      );
      // Give the async failure a beat, then prove nothing moved.
      await Future<void>.delayed(Duration.zero);
      expect(await readMetadata(), current);
    });

    test('a fresh install (no metadata yet) snapshots {} and proceeds',
        () async {
      await service()
          .restoreBackup(_zipWithMetadata(backupMeta), (_) {}, replace: true);
      final entries = await vault().list();
      expect(entries, hasLength(1));
      final snapshot =
          jsonDecode(utf8.decode((await vault().read(entries.single.id))!))
              as Map<String, dynamic>;
      expect((snapshot['payload'] as Map)['metadata'], <String, Object?>{});
    });
  });

  group('create: verify by read-back + settings included', () {
    test(
        'createBackup returns a BackupInfo validated from the ACTUAL '
        'encoded bytes and the archive carries settings.json', () async {
      await writeMetadata(backupMeta);
      await storage.initialize();

      final out = '${tmp.path}/out.zip';
      final info = await service().createBackup(out, (_) {});

      expect(info.clipCount, 1,
          reason: '"Backed up and verified — N clips" needs the read-back');
      expect(info.clipFileCount, 0,
          reason: 'REVIEW FIX: the receipt counts the .mp4 files actually '
              'in the archive (none here — the seeded metadata points at '
              'clips that do not exist on disk), separately from the index '
              'count');

      final written = await File(out).readAsBytes();
      final archive = ZipDecoder().decodeBytes(written);
      final settingsEntry = archive.findFile('settings.json');
      expect(settingsEntry, isNotNull,
          reason: 'settings were silently missing from every PT backup');
      final settings = jsonDecode(
          utf8.decode(settingsEntry!.content as List<int>));
      expect(settings['theme_mode'], 1);
      expect(settings.containsKey('clips_migrated_v2'), isFalse,
          reason: 'REVIEW FIX: only allowlisted user-facing settings '
              'travel — internal/migration flags must not');
    });
  });

  group('restore: settings behavior', () {
    test('replace-mode applies allowlisted backup settings', () async {
      await writeMetadata({'clips': <String, Object?>{}});
      await service().restoreBackup(
          _zipWithMetadata(backupMeta, settings: {'theme_mode': 2}), (_) {},
          replace: true);
      expect(prefs.getInt('theme_mode'), 2);
    });

    test(
        'REVIEW FIX: a non-allowlisted or wrong-typed settings key is '
        'ignored (no pref pollution, no persisted type crash)', () async {
      await writeMetadata({'clips': <String, Object?>{}});
      await service().restoreBackup(
          _zipWithMetadata(backupMeta, settings: {
            'clips_migrated_v2': false, // internal — a crafted zip must not flip it
            'theme_mode': 'dark', // wrong type for an allowlisted key
            'evil_new_key': 'x',
          }),
          (_) {},
          replace: true);
      expect(prefs.getBool('clips_migrated_v2'), isTrue);
      expect(prefs.getInt('theme_mode'), 1,
          reason: 'a wrong-typed value must not clobber (or crash) the pref');
      expect(prefs.containsKey('evil_new_key'), isFalse);
    });

    test('merge-mode fills only MISSING keys (local settings win)', () async {
      await writeMetadata({'clips': <String, Object?>{}});
      await service().restoreBackup(
          _zipWithMetadata(backupMeta,
              settings: {'theme_mode': 2, 'date_format': 'yyyyMmDd'}),
          (_) {});
      expect(prefs.getInt('theme_mode'), 1,
          reason: 'merge must not clobber a local choice');
      expect(prefs.getString('date_format'), 'yyyyMmDd',
          reason: 'a key this device never set comes along');
    });

    test(
        'REVIEW FIX: merge-mode UNIONS list-valued settings instead of '
        'short-circuiting on containsKey', () async {
      await writeMetadata({'clips': <String, Object?>{}});
      await service().restoreBackup(
          _zipWithMetadata(backupMeta, settings: {
            'pinned_tags': ['christmas']
          }),
          (_) {});
      expect(prefs.getStringList('pinned_tags')!.toSet(),
          {'birthday', 'christmas'},
          reason: 'restoring to recover lost pins must actually recover them');
    });

    test('an OLD archive without settings.json restores fine', () async {
      await writeMetadata({'clips': <String, Object?>{}});
      await service()
          .restoreBackup(_zipWithMetadata(backupMeta), (_) {}, replace: true);
      expect(prefs.getInt('theme_mode'), 1);
      expect((await readMetadata())['clips'], isNotEmpty);
    });
  });

  group('restore FROM a vault snapshot', () {
    test(
        'restoreMetadataSnapshot writes the snapshot back — after taking a '
        'fresh pre-restore snapshot of what was current', () async {
      final old = {
        'clips': {
          '2026-01-01': [
            {'id': 'c-old', 'filePath': 'clips/c-old.mp4'}
          ]
        }
      };
      await writeMetadata(old);
      final svc = service();

      // A restore happens (snapshotting `old`), then the user regrets it.
      await svc.restoreBackup(_zipWithMetadata(backupMeta), (_) {},
          replace: true);
      final rollbackId = (await vault().list()).single.id;

      await svc.restoreMetadataSnapshot(rollbackId, (_) {});

      expect(await readMetadata(), old,
          reason: 'the rollback restores the pre-mistake state');
      expect(prefs.getInt('theme_mode'), 1,
          reason: 'REVIEW FIX: settings the restore clobbered roll back '
              'with the snapshot');
      final labels = (await vault().list()).map((e) => e.label);
      expect(labels.where((l) => l == VaultLabel.preRestore).length, 2,
          reason: 'rolling back is itself a restore and gets its own net');
    });

    test('restoring a missing snapshot id throws StateError, changes nothing',
        () async {
      await writeMetadata({'marker': 'still here'});
      expect(() => service().restoreMetadataSnapshot('nope.json', (_) {}),
          throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      expect((await readMetadata())['marker'], 'still here');
    });

    test(
        'REVIEW FIX: a corrupt snapshot is refused — never silently written '
        'over the live journal index', () async {
      await writeMetadata({'marker': 'still here'});
      final entry = await vault()
          .save(Uint8List.fromList([0xFF, 0x00]), label: VaultLabel.manual);
      await expectLater(
          service().restoreMetadataSnapshot(entry.id, (_) {}),
          throwsA(isA<StateError>()));
      expect((await readMetadata())['marker'], 'still here');
    });
  });

  group('validateBackup: settings presence (honest replace copy)', () {
    // The replace confirmation branches its copy on whether the archive
    // carries settings.json — legacy v1 archives never do, and a
    // replace-mode restore of one leaves current settings untouched.
    test('a v2 archive with settings.json reports hasSettings true',
        () async {
      final info = await service().validateBackup(
          _zipWithMetadata(backupMeta, settings: {'theme_mode': 2}));
      expect(info.hasSettings, isTrue);
    });

    test('a legacy v1 archive without settings.json reports hasSettings '
        'false', () async {
      final info = await service().validateBackup(_zipWithMetadata(backupMeta));
      expect(info.hasSettings, isFalse);
    });
  });
}
