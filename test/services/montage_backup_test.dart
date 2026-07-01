// Montages are the point of the app — the backup must carry them.
//
// Before this suite, a backup carried only the montage's metadata row
// (title, date range, clip list) while the MP4 stayed behind with the old
// install; after a device migration the row pointed at a file the new
// applicationId is not allowed to open, and the player surfaced a raw
// PlatformException. Now:
//   * createBackup includes each montage file under compilations/
//     (default ON, opt-out), skipping files it cannot read,
//   * restoreBackup extracts compilations/ into the app-private compiled
//     dir, and the sanitizer pins every restored compilation filePath
//     there — which also closes the crafted-backup hole where a foreign
//     compilation path was trusted verbatim by share/delete/next-backup,
//   * validateBackup reports the honest montage-file count.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late StorageService storage;
  late SharedPreferences prefs;

  BackupService service() => BackupService(
        storage,
        vault: BackupVault(
          InMemoryVaultStore(),
          appId: 'punctum',
          extension: 'json',
        ),
        prefs: prefs,
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pt_montage_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
    await storage.initialize();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Writes a real montage file and registers its Compilation row.
  Future<Compilation> addMontage(String name, List<int> bytes) async {
    final path = '${tmp.path}/compiled/$name';
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(bytes);
    final comp = Compilation(
      id: name,
      title: name,
      filePath: path,
      clipIds: const [],
      createdAt: DateTime(2026, 7, 1),
    );
    await storage.addCompilation(comp);
    return comp;
  }

  Uint8List montageZip({
    required Map<String, dynamic> metadata,
    Map<String, List<int>> montageFiles = const {},
  }) {
    final archive = Archive();
    final metaBytes = utf8.encode(jsonEncode(metadata));
    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));
    for (final e in montageFiles.entries) {
      archive.addFile(
          ArchiveFile('compilations/${e.key}', e.value.length, e.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  group('createBackup carries montage files', () {
    test('includes each montage under compilations/ by default', () async {
      await addMontage('jul.mp4', List<int>.filled(64, 7));
      await addMontage('aug.mp4', List<int>.filled(32, 8));

      final out = '${tmp.path}/backup.zip';
      final info = await service().createBackup(out, (_) {});

      final decoded =
          ZipDecoder().decodeBytes(await File(out).readAsBytes());
      final names = decoded.map((e) => e.name).toList();
      expect(names, contains('compilations/jul.mp4'));
      expect(names, contains('compilations/aug.mp4'));
      expect(info.montageFileCount, 2,
          reason: 'the verified read-back must report the honest count');
    });

    test('omits montage files when includeMontages is false', () async {
      await addMontage('jul.mp4', List<int>.filled(64, 7));

      final out = '${tmp.path}/backup.zip';
      final info =
          await service().createBackup(out, (_) {}, includeMontages: false);

      final decoded =
          ZipDecoder().decodeBytes(await File(out).readAsBytes());
      expect(
          decoded.map((e) => e.name).where(
              (n) => n.startsWith('compilations/')),
          isEmpty);
      expect(info.montageFileCount, 0);
      expect(info.compilationCount, 1,
          reason: 'the metadata row still travels — only the MP4 is opted out');
    });

    test('skips a montage whose file is unreadable without failing', () async {
      // The migrated-device reality: the row exists, the old install's file
      // does not. Backup must not fail and must not fabricate an entry.
      final ghost = Compilation(
        id: 'ghost',
        title: 'ghost',
        filePath: '${tmp.path}/compiled/ghost.mp4', // never written
        clipIds: const [],
        createdAt: DateTime(2026, 1, 1),
      );
      await storage.addCompilation(ghost);
      await addMontage('real.mp4', List<int>.filled(16, 1));

      final out = '${tmp.path}/backup.zip';
      final info = await service().createBackup(out, (_) {});

      final decoded =
          ZipDecoder().decodeBytes(await File(out).readAsBytes());
      final names = decoded.map((e) => e.name).toList();
      expect(names, contains('compilations/real.mp4'));
      expect(names, isNot(contains('compilations/ghost.mp4')));
      expect(info.montageFileCount, 1);
      expect(info.compilationCount, 2);
    });

    test('getBackupSize counts montage bytes only when included', () async {
      await addMontage('jul.mp4', List<int>.filled(5000, 7));
      final withMontages = await service().getBackupSize();
      final withoutMontages =
          await service().getBackupSize(includeMontages: false);
      expect(withMontages - withoutMontages, 5000);
    });
  });

  group('restoreBackup brings montages home', () {
    test('extracts compilations/ into the private compiled dir and pins the row',
        () async {
      final zip = montageZip(
        metadata: {
          'clips': <String, dynamic>{},
          'compilations': [
            {
              'id': 'm1',
              'title': 'Migrated',
              // The old install's absolute path — must NOT be trusted.
              'filePath':
                  '/storage/emulated/0/Movies/OneSecondADay/compilations/m1.mp4',
              'clipIds': <String>[],
              'createdAt': '2026-06-01T00:00:00.000',
            },
          ],
          'knownPeople': <String, dynamic>{},
        },
        montageFiles: {'m1.mp4': List<int>.filled(48, 9)},
      );

      await service().restoreBackup(zip, (_) {});

      final restoredFile = File('${tmp.path}/compiled/m1.mp4');
      expect(await restoredFile.exists(), isTrue,
          reason: 'the montage MP4 must be extracted into our own sandbox');
      expect((await restoredFile.readAsBytes()).length, 48);

      expect(storage.compilations, hasLength(1));
      expect(storage.compilations.first.filePath, '${tmp.path}/compiled/m1.mp4',
          reason: 'the restored row must point at the extracted copy, '
              'not the old install\'s path');
    });

    test('a legacy backup with rows but no montage files still restores',
        () async {
      final zip = montageZip(
        metadata: {
          'clips': <String, dynamic>{},
          'compilations': [
            {
              'id': 'old1',
              'title': 'Legacy row',
              'filePath': '/data/user/0/old.app/compiled/old1.mp4',
              'clipIds': <String>[],
              'createdAt': '2025-12-01T00:00:00.000',
            },
          ],
          'knownPeople': <String, dynamic>{},
        },
      );

      await service().restoreBackup(zip, (_) {});

      expect(storage.compilations, hasLength(1));
      expect(storage.compilations.first.filePath,
          '${tmp.path}/compiled/old1.mp4',
          reason: 'even a dangling row gets pinned into our sandbox — the '
              'screen then offers a recompile instead of an EACCES crash');
    });
  });

  group('sanitizeRestoredMetadata pins compilation paths', () {
    test('a foreign or traversal compilation filePath is pinned by basename',
        () {
      final out = BackupService.sanitizeRestoredMetadata(
        {
          'compilations': [
            {'id': 'a', 'filePath': '/data/data/app/databases/secret.db'},
            {'id': 'b', 'filePath': '../../../etc/passwd'},
          ],
        },
        clipsDir: '/app/clips',
        thumbnailsDir: '/app/thumbnails',
        facesDir: '/app/faces',
        compiledDir: '/app/compiled',
      );
      final comps = out['compilations'] as List;
      expect((comps[0] as Map)['filePath'], '/app/compiled/secret.db',
          reason: 'share/delete/next-backup all trust this path — it must '
              'never point outside the compiled dir');
      expect((comps[1] as Map)['filePath'], '/app/compiled/passwd');
    });
  });

  group('validateBackup montage honesty', () {
    test('montageFileCount reflects the files actually present', () async {
      final zip = montageZip(
        metadata: {
          'clips': <String, dynamic>{},
          'compilations': [
            {
              'id': 'x',
              'title': 'X',
              'filePath': '/x.mp4',
              'clipIds': <String>[],
              'createdAt': '2026-01-01T00:00:00.000',
            },
            {
              'id': 'y',
              'title': 'Y',
              'filePath': '/y.mp4',
              'clipIds': <String>[],
              'createdAt': '2026-01-01T00:00:00.000',
            },
          ],
        },
        montageFiles: {'x.mp4': List<int>.filled(8, 1)},
      );

      final info = await service().validateBackup(zip);
      expect(info.compilationCount, 2, reason: 'rows declared');
      expect(info.montageFileCount, 1, reason: 'files actually aboard');
    });
  });
}
