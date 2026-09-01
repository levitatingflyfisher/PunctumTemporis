// A deliberate delete does not ask; it happens at once and offers an Undo
// that never times out (fleet delete ruling, 2026-09-26). For that Undo to
// be real, a delete must take the clip off the calendar WITHOUT destroying
// its files, and only an Undo that lapses may destroy them.
//
// These tests pin the three halves of that contract on the real storage
// service over a real directory:
//   * removeClip takes the row out of metadata and leaves the files,
//   * restoreClip puts the same row back where it was (a day's first clip is
//     its thumbnail, so the position matters),
//   * purgeRemoved destroys the files, and a pending removal that outlived a
//     restart is purged on the next start, so no file is orphaned forever.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
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
  late SharedPreferences prefs;
  late StorageService storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pt_soft_delete_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
    await storage.initialize();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<Clip> addClip(String id, String date) async {
    final video = File('${tmp.path}/clips/$id.mp4');
    final thumb = File('${tmp.path}/thumbnails/$id.jpg');
    await video.writeAsBytes([1, 2, 3]);
    await thumb.writeAsBytes([4, 5, 6]);
    final clip = Clip(
      id: id,
      date: date,
      filePath: video.path,
      thumbnailPath: thumb.path,
      type: ClipType.video,
      createdAt: DateTime(2026, 9, 1),
    );
    await storage.addClip(clip);
    return clip;
  }

  test('removeClip takes the clip off the calendar and keeps its files',
      () async {
    final clip = await addClip('a', '2026-09-04');

    final removed = await storage.removeClip('a');

    expect(removed, isNotNull);
    expect(storage.hasClipForDate('2026-09-04'), isFalse);
    expect(File(clip.filePath).existsSync(), isTrue);
    expect(File(clip.thumbnailPath!).existsSync(), isTrue);
  });

  test('restoreClip puts it back in the same place in its day', () async {
    await addClip('first', '2026-09-04');
    await addClip('second', '2026-09-04');
    await addClip('third', '2026-09-04');

    final removed = await storage.removeClip('first');
    await storage.restoreClip(removed!);

    expect(storage.getClipsForDate('2026-09-04').map((c) => c.id),
        ['first', 'second', 'third']);
  });

  test('restore survives a reload of the metadata file', () async {
    await addClip('a', '2026-09-04');
    final removed = await storage.removeClip('a');
    await storage.restoreClip(removed!);

    final reloaded = StorageService(prefs);
    await reloaded.initialize();
    expect(reloaded.hasClipForDate('2026-09-04'), isTrue);
  });

  test('purgeRemoved destroys the files of a removal nobody undid', () async {
    final clip = await addClip('a', '2026-09-04');
    final removed = await storage.removeClip('a');

    await storage.purgeRemoved(removed!);

    expect(File(clip.filePath).existsSync(), isFalse);
    expect(File(clip.thumbnailPath!).existsSync(), isFalse);
  });

  test('a removal still pending at shutdown is purged on the next start',
      () async {
    final clip = await addClip('a', '2026-09-04');
    await storage.removeClip('a');

    // The app died with the Undo still on screen: no purge, no restore.
    final next = StorageService(prefs);
    await next.initialize();
    await next.purgePendingRemovals();

    expect(next.hasClipForDate('2026-09-04'), isFalse);
    expect(File(clip.filePath).existsSync(), isFalse);
    expect(File(clip.thumbnailPath!).existsSync(), isFalse);
  });

  test('an undone removal is not purged on the next start', () async {
    final clip = await addClip('a', '2026-09-04');
    final removed = await storage.removeClip('a');
    await storage.restoreClip(removed!);

    final next = StorageService(prefs);
    await next.initialize();
    await next.purgePendingRemovals();

    expect(next.hasClipForDate('2026-09-04'), isTrue);
    expect(File(clip.filePath).existsSync(), isTrue);
  });

  test('restore and remove both tell listeners the clips changed', () async {
    await addClip('a', '2026-09-04');
    var changes = 0;
    storage.changes.addListener(() => changes++);

    final removed = await storage.removeClip('a');
    await storage.restoreClip(removed!);

    expect(changes, 2);
  });

  group('montages', () {
    Future<Compilation> addMontage(String id) async {
      final file = File('${tmp.path}/compiled/$id.mp4');
      await file.parent.create(recursive: true);
      await file.writeAsBytes([7, 8, 9]);
      final comp = Compilation(
        id: id,
        title: id,
        filePath: file.path,
        clipIds: const [],
        createdAt: DateTime(2026, 9, 1),
      );
      await storage.addCompilation(comp);
      return comp;
    }

    test('removeCompilation keeps the file; restore puts the row back',
        () async {
      await addMontage('m1');
      final m2 = await addMontage('m2');

      final removed = await storage.removeCompilation('m2');
      expect(storage.compilations.map((c) => c.id), ['m1']);
      expect(File(m2.filePath).existsSync(), isTrue);

      await storage.restoreCompilation(removed!);
      expect(storage.compilations.map((c) => c.id), ['m1', 'm2']);
    });

    test('purge destroys the montage file; a pending one is purged on start',
        () async {
      final m1 = await addMontage('m1');
      final m2 = await addMontage('m2');

      final r1 = await storage.removeCompilation('m1');
      await storage.purgeRemovedCompilation(r1!);
      expect(File(m1.filePath).existsSync(), isFalse);

      await storage.removeCompilation('m2');
      final next = StorageService(prefs);
      await next.initialize();
      await next.purgePendingRemovals();
      expect(File(m2.filePath).existsSync(), isFalse);
    });
  });
}
