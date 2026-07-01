// Person-name path-traversal guard (fleet finding, backup_service.dart:100 +
// storage_service.dart saveFaceImage).
//
// A person name is interpolated into '$facesDir/$name.jpg' at THREE file-op
// sites: StorageService.saveFaceImage (write), BackupService.createBackup
// (read + pack into the shared zip) and BackupService.getBackupSize (read).
// sanitizeRestoredMetadata already drops unsafe knownPeople keys at the
// restore boundary, but a user-entered name ('../x') never crossed that
// boundary, and defense-in-depth demands the guard at every use site. These
// tests pin the shared isSafePersonName guard and both behavioral paths.

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/services/backup_service.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/utils/person_name.dart';
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

  group('isSafePersonName (pure guard)', () {
    test('accepts ordinary names', () {
      expect(isSafePersonName('Alice'), isTrue);
      expect(isSafePersonName('Mary Jane'), isTrue);
      expect(isSafePersonName('José'), isTrue);
    });

    test('rejects separators, traversal, quotes and control chars', () {
      expect(isSafePersonName(''), isFalse);
      expect(isSafePersonName('a/b'), isFalse);
      expect(isSafePersonName(r'a\b'), isFalse);
      expect(isSafePersonName('..'), isFalse);
      expect(isSafePersonName('../../sdcard/DCIM/private'), isFalse);
      expect(isSafePersonName('a"b'), isFalse);
      expect(isSafePersonName('a\nb'), isFalse);
      expect(isSafePersonName('a\rb'), isFalse);
    });
  });

  group('face-path file ops route through the guard', () {
    late Directory tmp;
    late StorageService storage;
    late SharedPreferences prefs;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('pt_faceguard_');
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    BackupService service() => BackupService(
          storage,
          vault: BackupVault(
            InMemoryVaultStore(),
            appId: 'punctum',
            extension: 'json',
          ),
          prefs: prefs,
        );

    test('saveFaceImage refuses a traversal name — nothing written outside '
        'the faces dir', () async {
      await storage.initialize();
      final src = File('${tmp.path}/src.jpg');
      await src.writeAsBytes([1, 2, 3]); // junk → crop falls back to copy

      await storage.saveFaceImage(
          '../escape', src.path, const Rect.fromLTWH(0, 0, 1, 1));

      expect(File('${tmp.path}/escape.jpg').existsSync(), isFalse,
          reason: "a name with '..' must never place a file above facesDir");
      final facesDir = Directory('${tmp.path}/faces');
      final leaked = facesDir.existsSync()
          ? facesDir.listSync(recursive: true)
          : <FileSystemEntity>[];
      expect(leaked, isEmpty,
          reason: 'the unsafe name must be rejected before any file op');
    });

    test('saveFaceImage still writes a safe name into the faces dir',
        () async {
      await storage.initialize();
      final src = File('${tmp.path}/src.jpg');
      await src.writeAsBytes([1, 2, 3]);

      await storage.saveFaceImage(
          'Alice', src.path, const Rect.fromLTWH(0, 0, 1, 1));

      expect(File('${tmp.path}/faces/Alice.jpg').existsSync(), isTrue);
    });

    test('createBackup does not read (or pack) a face path for an unsafe '
        'knownPeople key', () async {
      // A pre-guard metadata.json (e.g. written before the sanitizer
      // existed) can still carry an unsafe key — the export side must not
      // trust it: '$facesDir/../secret.jpg' resolves OUTSIDE faces/ and
      // would exfiltrate a foreign file into the shared zip. The faces dir
      // must exist for the OS to resolve the traversal (it does on any
      // device that ever saved a face).
      await Directory('${tmp.path}/faces').create(recursive: true);
      await File('${tmp.path}/secret.jpg').writeAsBytes([9, 9, 9]);
      await File('${tmp.path}/metadata.json').writeAsString(jsonEncode({
        'clips': <String, dynamic>{},
        'compilations': <dynamic>[],
        'knownPeople': {
          '../secret': [
            [0.1, 0.2]
          ],
        },
      }));
      await storage.initialize();
      expect(storage.knownPeople.keys, contains('../secret'),
          reason: 'precondition: the unsafe key is live in memory');

      final out = '${tmp.path}/backup.zip';
      await service().createBackup(out, (_) {});

      final decoded = ZipDecoder().decodeBytes(await File(out).readAsBytes());
      final faceEntries =
          decoded.map((e) => e.name).where((n) => n.startsWith('faces/'));
      expect(faceEntries, isEmpty,
          reason: 'an unsafe person key must be skipped, never used to '
              'build a read path');
      expect(
          decoded.map((e) => e.name).where((n) => n.contains('..')), isEmpty);
    });

    test('getBackupSize skips the face path for an unsafe knownPeople key',
        () async {
      await Directory('${tmp.path}/faces').create(recursive: true);
      await File('${tmp.path}/secret.jpg').writeAsBytes(List.filled(4096, 7));
      await File('${tmp.path}/metadata.json').writeAsString(jsonEncode({
        'clips': <String, dynamic>{},
        'compilations': <dynamic>[],
        'knownPeople': {
          '../secret': [
            [0.1, 0.2]
          ],
        },
      }));
      await storage.initialize();

      final size = await service().getBackupSize();
      expect(size, 10000,
          reason: 'only the metadata-overhead estimate — the out-of-faces '
              'file must not be counted');
    });
  });
}
