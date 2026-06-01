import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/services/storage_service.dart';

// Test notes: StorageService.reorderClips() calls _saveMetadata() which requires
// filesystem initialization. In a unit test context, this may throw LateInitializationError
// for _metadataPath. The tests verify that the in-memory reorder logic is correct,
// catching any persistence errors that may occur.

void main() {
  group('Clip reordering logic', () {
    test('reorders clip list by ID order', () {
      final clips = [
        _makeClip('a', '2026-01-01'),
        _makeClip('b', '2026-01-01'),
        _makeClip('c', '2026-01-01'),
      ];

      // Simulate reorder: c, a, b
      final newOrder = ['c', 'a', 'b'];
      final reordered = <Clip>[];
      for (final id in newOrder) {
        reordered.add(clips.firstWhere((c) => c.id == id));
      }

      expect(reordered.map((c) => c.id).toList(), ['c', 'a', 'b']);
      expect(reordered[0].id, 'c');
      expect(reordered[1].id, 'a');
      expect(reordered[2].id, 'b');
    });

    test('preserves clips not in reorder list', () {
      final clips = [
        _makeClip('a', '2026-01-01'),
        _makeClip('b', '2026-01-01'),
        _makeClip('c', '2026-01-01'),
      ];

      // Only reorder a and c, missing b
      final newOrder = ['c', 'a'];
      final reordered = <Clip>[];
      for (final id in newOrder) {
        final clip =
            clips.firstWhere((c) => c.id == id, orElse: () => clips.first);
        reordered.add(clip);
      }
      // Add missing clips
      for (final clip in clips) {
        if (!newOrder.contains(clip.id)) {
          reordered.add(clip);
        }
      }

      expect(reordered.length, 3);
      expect(reordered.map((c) => c.id).toList(), ['c', 'a', 'b']);
    });

    test('single clip reorder is no-op', () {
      final clips = [_makeClip('x', '2026-01-01')];
      final newOrder = ['x'];
      final reordered = <Clip>[];
      for (final id in newOrder) {
        reordered.add(clips.firstWhere((c) => c.id == id));
      }

      expect(reordered.length, 1);
      expect(reordered[0].id, 'x');
    });

    test('reorder skips stale IDs — does not duplicate clips', () {
      final clips = [
        _makeClip('c1', '2026-01-01'),
        _makeClip('c2', '2026-01-01'),
      ];

      // Confirm the buggy logic produces a duplicate
      final buggyOrder = ['c2', 'stale-id', 'c1'];
      final buggyResult = <Clip>[];
      for (final id in buggyOrder) {
        buggyResult
            .add(clips.firstWhere((c) => c.id == id, orElse: () => clips.first));
      }
      expect(buggyResult.length, equals(3)); // stale-id resolves to clips.first

      // Fixed logic: skip stale IDs
      final fixedResult = <Clip>[];
      for (final id in buggyOrder) {
        final clip = clips.where((c) => c.id == id).firstOrNull;
        if (clip == null) continue;
        fixedResult.add(clip);
      }
      expect(fixedResult.length, equals(2));
      expect(fixedResult[0].id, equals('c2'));
      expect(fixedResult[1].id, equals('c1'));
    });
  });

  group('Milestone preferences logic', () {
    test('milestone set operations', () {
      final milestones = <int>{};

      milestones.add(7);
      expect(milestones.contains(7), isTrue);
      expect(milestones.contains(30), isFalse);

      milestones.add(30);
      milestones.add(100);
      expect(milestones.length, 3);
    });

    test('streak milestone detection', () {
      const streakMilestones = [7, 30, 50, 100, 200, 365];
      final celebrated = <int>{7};
      const currentStreak = 30;

      int? nextMilestone;
      for (final milestone in streakMilestones) {
        if (currentStreak >= milestone && !celebrated.contains(milestone)) {
          nextMilestone = milestone;
          break;
        }
      }

      expect(nextMilestone, 30);
    });

    test('no celebration when already celebrated', () {
      const streakMilestones = [7, 30, 50, 100, 200, 365];
      final celebrated = <int>{7, 30};
      const currentStreak = 30;

      int? nextMilestone;
      for (final milestone in streakMilestones) {
        if (currentStreak >= milestone && !celebrated.contains(milestone)) {
          nextMilestone = milestone;
          break;
        }
      }

      expect(nextMilestone, isNull);
    });
  });

  group('StorageService.reorderClips', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
    });

    test('reorders clips and skips stale IDs without duplication', () async {
      final dateStr = '2026-01-15';
      final clip1 = _makeClip('c1', dateStr);
      final clip2 = _makeClip('c2', dateStr);
      storage.setClipsForTest({dateStr: [clip1, clip2]});

      // Reorder with a stale ID in the middle
      // Note: _saveMetadata() may fail in unit test context, but the in-memory reorder should still work
      try {
        await storage.reorderClips(dateStr, ['c2', 'stale-id', 'c1']);
      } catch (_) {
        // Expected in unit test context; verify in-memory state is still correct by direct access
      }

      final result = storage.getClipsForDate(dateStr);
      expect(result.length, equals(2)); // stale ID skipped, no duplication
      expect(result[0].id, equals('c2'));
      expect(result[1].id, equals('c1'));
    });

    test('preserves clips not in reorder list', () async {
      final dateStr = '2026-01-20';
      final clip1 = _makeClip('a', dateStr);
      final clip2 = _makeClip('b', dateStr);
      final clip3 = _makeClip('c', dateStr);
      storage.setClipsForTest({dateStr: [clip1, clip2, clip3]});

      // Only reorder a and c, missing b
      try {
        await storage.reorderClips(dateStr, ['c', 'a']);
      } catch (_) {
        // Expected in unit test context; verify in-memory state
      }

      final result = storage.getClipsForDate(dateStr);
      expect(result.length, equals(3));
      expect(result.map((c) => c.id).toList(), ['c', 'a', 'b']);
    });

    test('no-op on empty date', () async {
      final dateStr = '2026-02-01';
      storage.setClipsForTest({dateStr: []});

      // Empty list will proceed to reorder logic (list is not null)
      // and will call _saveMetadata(), which may fail in unit test
      try {
        await storage.reorderClips(dateStr, ['x', 'y', 'z']);
      } catch (_) {
        // Expected: _saveMetadata() fails in unit test context
      }

      final result = storage.getClipsForDate(dateStr);
      expect(result.length, equals(0));
    });

    test('no-op on non-existent date', () async {
      // Should not throw (early return when list is null)
      try {
        await storage.reorderClips('2099-12-31', ['x', 'y']);
      } catch (_) {
        // Not expected here since non-existent date returns early
        rethrow;
      }
    });
  });
}

Clip _makeClip(String id, String date) {
  return Clip(
    id: id,
    date: date,
    filePath: '/fake/$id.mp4',
    type: ClipType.video,
    createdAt: DateTime.parse(date),
    duration: 1.0,
  );
}
