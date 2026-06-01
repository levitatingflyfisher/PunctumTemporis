import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';

void main() {
  group('AudioSegment', () {
    test('construction with defaults', () {
      final seg = AudioSegment(
        filePath: '/audio/track.mp3',
        fileName: 'track.mp3',
      );

      expect(seg.filePath, '/audio/track.mp3');
      expect(seg.fileName, 'track.mp3');
      expect(seg.startTimeInCompilation, 0);
      expect(seg.audioOffset, 0);
      expect(seg.duration, isNull);
      expect(seg.volume, 0.3);
    });

    test('construction with all fields', () {
      final seg = AudioSegment(
        filePath: '/audio/track.mp3',
        fileName: 'track.mp3',
        startTimeInCompilation: 5.0,
        audioOffset: 10.0,
        duration: 30.0,
        volume: 0.8,
      );

      expect(seg.startTimeInCompilation, 5.0);
      expect(seg.audioOffset, 10.0);
      expect(seg.duration, 30.0);
      expect(seg.volume, 0.8);
    });

    test('copyWith preserves unchanged fields', () {
      final seg = AudioSegment(
        filePath: '/audio/track.mp3',
        fileName: 'track.mp3',
        startTimeInCompilation: 5.0,
        audioOffset: 10.0,
        duration: 30.0,
        volume: 0.8,
      );

      final copy = seg.copyWith(volume: 0.5);

      expect(copy.filePath, '/audio/track.mp3');
      expect(copy.fileName, 'track.mp3');
      expect(copy.startTimeInCompilation, 5.0);
      expect(copy.audioOffset, 10.0);
      expect(copy.duration, 30.0);
      expect(copy.volume, 0.5);
    });

    test('copyWith overrides specified fields', () {
      final seg = AudioSegment(
        filePath: '/audio/track.mp3',
        fileName: 'track.mp3',
      );

      final copy = seg.copyWith(
        startTimeInCompilation: 3.0,
        audioOffset: 2.0,
        duration: 10.0,
      );

      expect(copy.startTimeInCompilation, 3.0);
      expect(copy.audioOffset, 2.0);
      expect(copy.duration, 10.0);
      expect(copy.filePath, '/audio/track.mp3');
    });
  });

  group('Clip', () {
    Clip makeClip({
      String id = 'test-id',
      String date = '2026-01-15',
      String filePath = '/clips/test.mp4',
      String? exifDate,
      List<String> tags = const [],
    }) {
      return Clip(
        id: id,
        date: date,
        filePath: filePath,
        type: ClipType.video,
        createdAt: DateTime(2026, 1, 15),
        exifDate: exifDate,
        tags: tags,
      );
    }

    test('fromJson / toJson roundtrip', () {
      final clip = Clip(
        id: 'abc123',
        date: '2026-02-10',
        filePath: '/clips/abc123.mp4',
        thumbnailPath: '/clips/abc123.jpg',
        type: ClipType.imported,
        createdAt: DateTime(2026, 2, 10, 14, 30),
        capturedAt: DateTime(2026, 2, 9, 12, 0),
        notes: 'A nice day',
        duration: 1.5,
        exifDate: '2026-02-09',
        tags: ['travel', 'sunset'],
        latitude: 48.8566,
        longitude: 2.3522,
        locationLabel: 'Paris',
        detectedFaces: ['Alice'],
      );

      final json = clip.toJson();
      final restored = Clip.fromJson(json);

      expect(restored.id, clip.id);
      expect(restored.date, clip.date);
      expect(restored.filePath, clip.filePath);
      expect(restored.thumbnailPath, clip.thumbnailPath);
      expect(restored.type, clip.type);
      expect(restored.createdAt, clip.createdAt);
      expect(restored.capturedAt, clip.capturedAt);
      expect(restored.notes, clip.notes);
      expect(restored.duration, clip.duration);
      expect(restored.exifDate, clip.exifDate);
      expect(restored.tags, clip.tags);
      expect(restored.latitude, clip.latitude);
      expect(restored.longitude, clip.longitude);
      expect(restored.locationLabel, clip.locationLabel);
      expect(restored.detectedFaces, clip.detectedFaces);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'min',
        'date': '2026-01-01',
        'filePath': '/clips/min.mp4',
        'type': 'video',
        'createdAt': '2026-01-01T00:00:00.000',
      };

      final clip = Clip.fromJson(json);

      expect(clip.thumbnailPath, isNull);
      expect(clip.capturedAt, isNull);
      expect(clip.notes, isNull);
      expect(clip.duration, isNull);
      expect(clip.exifDate, isNull);
      expect(clip.tags, isEmpty);
      expect(clip.latitude, isNull);
      expect(clip.longitude, isNull);
      expect(clip.locationLabel, isNull);
      expect(clip.detectedFaces, isEmpty);
    });

    test('copyWith modifies tag list', () {
      final clip = makeClip(tags: ['travel']);
      final updated = clip.copyWith(tags: ['travel', 'sunset']);

      expect(updated.tags, ['travel', 'sunset']);
      expect(clip.tags, ['travel']); // original unchanged
    });

    test('hasDateMismatch is true when exifDate differs from date', () {
      final clip = makeClip(date: '2026-01-15', exifDate: '2026-01-14');
      expect(clip.hasDateMismatch, isTrue);
    });

    test('hasDateMismatch is false when exifDate matches date', () {
      final clip = makeClip(date: '2026-01-15', exifDate: '2026-01-15');
      expect(clip.hasDateMismatch, isFalse);
    });

    test('hasDateMismatch is false when exifDate is null', () {
      final clip = makeClip(date: '2026-01-15', exifDate: null);
      expect(clip.hasDateMismatch, isFalse);
    });

    test('fromJson handles unknown type gracefully', () {
      final json = {
        'id': 'x',
        'date': '2026-01-01',
        'filePath': '/clips/x.mp4',
        'type': 'unknown_type',
        'createdAt': '2026-01-01T00:00:00.000',
      };

      final clip = Clip.fromJson(json);
      expect(clip.type, ClipType.video); // falls back to video
    });

    test('Clip.fromJson handles integer duration without crashing', () {
      final json = {
        'id': 'test-id',
        'date': '2026-01-01',
        'filePath': '/clips/test.mp4',
        'thumbnailPath': '/thumbnails/test.jpg',
        'type': 'video',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'duration': 1,   // integer, not 1.0
        'tags': <String>[],
      };
      final clip = Clip.fromJson(json);
      expect(clip.duration, 1.0);
    });

    test('Compilation.fromJson handles integer duration without crashing', () {
      final json = {
        'id': 'comp-id',
        'title': 'Test',
        'filePath': '/compilations/test.mp4',
        'clipIds': <String>[],
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'duration': 2,   // integer
      };
      final comp = Compilation.fromJson(json);
      expect(comp.duration, 2.0);
    });

    test('copyWith can clear nullable fields to null', () {
      final clip = Clip(
        id: 'id1',
        date: '2026-01-01',
        filePath: '/clips/a.mp4',
        thumbnailPath: '/thumbs/a.jpg',
        type: ClipType.video,
        createdAt: DateTime(2026, 1, 1),
        locationLabel: 'Paris',
        latitude: 48.8566,
        longitude: 2.3522,
        notes: 'holiday',
        exifDate: '2026-01-01',
        capturedAt: DateTime(2026, 1, 1, 12),
      );

      final cleared = clip.copyWith(
        locationLabel: null,
        latitude: null,
        longitude: null,
        thumbnailPath: null,
        notes: null,
        exifDate: null,
        capturedAt: null,
      );

      expect(cleared.locationLabel, isNull);
      expect(cleared.latitude, isNull);
      expect(cleared.longitude, isNull);
      expect(cleared.thumbnailPath, isNull);
      expect(cleared.notes, isNull);
      expect(cleared.exifDate, isNull);
      expect(cleared.capturedAt, isNull);
      // Non-nullable fields and lists unchanged
      expect(cleared.id, 'id1');
      expect(cleared.filePath, '/clips/a.mp4');
      expect(cleared.tags, isEmpty);
    });

    test('copyWith preserves nullable fields when not specified', () {
      final clip = Clip(
        id: 'id2',
        date: '2026-01-01',
        filePath: '/clips/b.mp4',
        type: ClipType.video,
        createdAt: DateTime(2026, 1, 1),
        locationLabel: 'London',
        latitude: 51.5,
        longitude: -0.12,
      );

      final copy = clip.copyWith(filePath: '/clips/b2.mp4');
      expect(copy.locationLabel, 'London'); // preserved when not specified
      expect(copy.latitude, 51.5);         // preserved when not specified
      expect(copy.filePath, '/clips/b2.mp4'); // changed
    });
  });
}
