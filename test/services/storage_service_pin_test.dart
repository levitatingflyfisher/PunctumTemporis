import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/services/storage_service.dart';

void main() {
  late StorageService svc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    svc = StorageService(prefs);
  });

  group('Pin-to-keep tags', () {
    test('pinTag adds to pinnedTags', () async {
      await svc.pinTag('birthday');
      expect(svc.pinnedTags, contains('birthday'));
    });

    test('unpinTag removes from pinnedTags', () async {
      await svc.pinTag('birthday');
      await svc.unpinTag('birthday');
      expect(svc.pinnedTags, isNot(contains('birthday')));
    });

    test('allTagsWithPinned includes pinned tags even with no clips', () async {
      await svc.pinTag('christmas');
      expect(svc.allTagsWithPinned, contains('christmas'));
    });

    test('allTagsWithPinned is union of live tags and pinned tags', () async {
      await svc.pinTag('pinned-only');
      // allTags is empty (no clips), but allTagsWithPinned includes the pinned one
      expect(svc.allTagsWithPinned.contains('pinned-only'), isTrue);
      expect(svc.allTags.contains('pinned-only'), isFalse);
    });

    test('multiple pinned tags are all preserved', () async {
      await svc.pinTag('alpha');
      await svc.pinTag('beta');
      await svc.pinTag('gamma');
      expect(svc.pinnedTags, containsAll(['alpha', 'beta', 'gamma']));
    });
  });

  group('Pin-to-keep locations', () {
    test('pinLocation adds to pinnedLocations', () async {
      await svc.pinLocation('Paris');
      expect(svc.pinnedLocations, contains('Paris'));
    });

    test('unpinLocation removes from pinnedLocations', () async {
      await svc.pinLocation('Paris');
      await svc.unpinLocation('Paris');
      expect(svc.pinnedLocations, isNot(contains('Paris')));
    });

    test('allLocationsWithPinned includes pinned locations with no clips', () async {
      await svc.pinLocation('Tokyo');
      expect(svc.allLocationsWithPinned, contains('Tokyo'));
    });

    test('allLocationsWithPinned is union of live locations and pinned', () async {
      await svc.pinLocation('pinned-city');
      expect(svc.allLocationsWithPinned.contains('pinned-city'), isTrue);
      expect(svc.allLocations.contains('pinned-city'), isFalse);
    });
  });

  group('replaceClipFile — copy-before-delete safety', () {
    test('replaceClipFile is a no-op when clip id does not exist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = StorageService(prefs);
      // _clips is empty — replaceClipFile iterates nothing and does not throw
      await service.replaceClipFile('no-such-id', '/tmp/nonexistent.mp4');
      expect(service.clips, isEmpty);
    });
  });

  group('getCurrentStreak — morning grace (no clip yet today)', () {
    test('returns non-zero when today has no clip but yesterday does', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yKey =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final clip = Clip(
        id: 'y1',
        date: yKey,
        filePath: '/clips/y1.mp4',
        thumbnailPath: '/thumbs/y1.jpg',
        type: ClipType.video,
        createdAt: yesterday,
      );
      storage.setClipsForTest({
        yKey: [clip]
      });

      expect(storage.getCurrentStreak(), equals(1));
    });

    test('returns 0 when both today and yesterday have no clips', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      // _clips starts as {} — no injection needed
      expect(storage.getCurrentStreak(), equals(0));
    });
  });
}
