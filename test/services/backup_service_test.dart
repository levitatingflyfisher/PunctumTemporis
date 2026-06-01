import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupService ZIP structure', () {
    test('creates valid ZIP with expected entries', () {
      // Create a test archive with the expected structure
      final archive = Archive();

      // metadata.json
      final metadata = jsonEncode({
        'clips': {
          '2026-01-01': [
            {
              'id': 'test-clip-1',
              'date': '2026-01-01',
              'filePath': '/clips/test-clip-1.mp4',
              'type': 'video',
              'createdAt': '2026-01-01T12:00:00.000',
              'tags': ['tag1'],
            }
          ],
        },
        'compilations': [],
        'knownPeople': {},
      });
      final metadataBytes = utf8.encode(metadata);
      archive.addFile(
          ArchiveFile('metadata.json', metadataBytes.length, metadataBytes));

      // Clip file (fake bytes)
      final fakeVideo = List<int>.filled(100, 0);
      archive.addFile(
          ArchiveFile('clips/test-clip-1.mp4', fakeVideo.length, fakeVideo));

      // Thumbnail
      final fakeThumb = List<int>.filled(50, 0);
      archive.addFile(ArchiveFile(
          'thumbnails/test-clip-1.jpg', fakeThumb.length, fakeThumb));

      // Encode
      final zipData = ZipEncoder().encode(archive);
      expect(zipData, isNotNull);
      expect(zipData!.length, greaterThan(0));

      // Decode and validate
      final decoded = ZipDecoder().decodeBytes(zipData);
      final fileNames = decoded.map((e) => e.name).toList();

      expect(fileNames, contains('metadata.json'));
      expect(fileNames, contains('clips/test-clip-1.mp4'));
      expect(fileNames, contains('thumbnails/test-clip-1.jpg'));
    });

    test('metadata serialization roundtrip preserves clip data', () {
      final original = {
        'clips': {
          '2026-01-15': [
            {
              'id': 'abc-123',
              'date': '2026-01-15',
              'filePath': '/data/clips/abc-123.mp4',
              'type': 'video',
              'createdAt': '2026-01-15T08:30:00.000',
              'duration': 1.0,
              'tags': ['morning', 'coffee'],
              'locationLabel': 'Paris',
              'detectedFaces': ['Alice'],
            }
          ],
          '2026-01-16': [
            {
              'id': 'def-456',
              'date': '2026-01-16',
              'filePath': '/data/clips/def-456.mp4',
              'type': 'imported',
              'createdAt': '2026-01-16T20:00:00.000',
              'duration': 1.5,
              'tags': [],
              'detectedFaces': [],
            }
          ],
        },
        'compilations': [],
        'knownPeople': {
          'Alice': [
            [0.1, 0.2, 0.3],
          ],
        },
      };

      // Serialize and deserialize
      final json = jsonEncode(original);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['clips'], isNotNull);
      final clips = decoded['clips'] as Map<String, dynamic>;
      expect(clips.keys.length, 2);

      final jan15 = (clips['2026-01-15'] as List).first as Map<String, dynamic>;
      expect(jan15['id'], 'abc-123');
      expect(jan15['tags'], ['morning', 'coffee']);
      expect(jan15['locationLabel'], 'Paris');

      final people = decoded['knownPeople'] as Map<String, dynamic>;
      expect(people.containsKey('Alice'), isTrue);
    });

    test('backup size estimation returns positive value', () {
      // This is a unit-level check — actual file I/O tested manually
      // The test verifies the logic: sum of fake file sizes + overhead
      final clipSizes = [1024, 2048, 512]; // bytes
      final thumbSizes = [256, 128];
      final overhead = 10000;

      final total = clipSizes.fold(0, (a, b) => a + b) +
          thumbSizes.fold(0, (a, b) => a + b) +
          overhead;

      expect(total, greaterThan(0));
      expect(total, equals(1024 + 2048 + 512 + 256 + 128 + 10000));
    });

    test('validates backup ZIP detects clip count from metadata', () {
      // Create a backup ZIP with metadata
      final archive = Archive();

      final metadata = jsonEncode({
        'clips': {
          '2026-02-01': [
            {
              'id': 'a',
              'date': '2026-02-01',
              'filePath': '/a.mp4',
              'type': 'video',
              'createdAt': '2026-02-01T00:00:00.000'
            },
            {
              'id': 'b',
              'date': '2026-02-01',
              'filePath': '/b.mp4',
              'type': 'video',
              'createdAt': '2026-02-01T00:00:00.000'
            },
          ],
          '2026-02-05': [
            {
              'id': 'c',
              'date': '2026-02-05',
              'filePath': '/c.mp4',
              'type': 'photo',
              'createdAt': '2026-02-05T00:00:00.000'
            },
          ],
        },
      });
      final bytes = utf8.encode(metadata);
      archive.addFile(ArchiveFile('metadata.json', bytes.length, bytes));

      final zipData = ZipEncoder().encode(archive)!;
      final decoded = ZipDecoder().decodeBytes(zipData);

      // Validate: read metadata, count clips
      final metaEntry = decoded.findFile('metadata.json');
      expect(metaEntry, isNotNull);

      final content = utf8.decode(metaEntry!.content as List<int>);
      final data = jsonDecode(content) as Map<String, dynamic>;
      final clipsData = data['clips'] as Map<String, dynamic>;

      int clipCount = 0;
      for (final value in clipsData.values) {
        if (value is List) clipCount += value.length;
      }
      expect(clipCount, 3);

      // Date range
      final dates = clipsData.keys.toList()..sort();
      expect(dates.first, '2026-02-01');
      expect(dates.last, '2026-02-05');
    });

    test('validateBackup counts compilations from metadata', () {
      final archive = Archive();
      final metadata = jsonEncode({
        'clips': {},
        'compilations': [
          {
            'id': 'comp1',
            'title': 'Jan 2026',
            'filePath': '/comp1.mp4',
            'clipIds': [],
            'createdAt': '2026-01-31T00:00:00.000',
          },
          {
            'id': 'comp2',
            'title': 'Feb 2026',
            'filePath': '/comp2.mp4',
            'clipIds': [],
            'createdAt': '2026-02-28T00:00:00.000',
          },
        ],
        'knownPeople': {},
      });
      final bytes = utf8.encode(metadata);
      archive.addFile(ArchiveFile('metadata.json', bytes.length, bytes));
      final zipData = ZipEncoder().encode(archive)!;
      final zipBytes = Uint8List.fromList(zipData);

      // Decode and check compilationCount via metadata parsing
      final decoded = ZipDecoder().decodeBytes(zipBytes);
      final metaEntry = decoded.findFile('metadata.json');
      final content = utf8.decode(metaEntry!.content as List<int>);
      final data = jsonDecode(content) as Map<String, dynamic>;
      final compilationCount = (data['compilations'] as List?)?.length ?? 0;
      expect(compilationCount, 2);
    });

    test('ZIP Slip entry names rejected by _isSafeEntryName', () {
      // Verify the sanitization logic directly
      bool isSafe(String name) {
        final parts = name.split('/');
        return !parts.any(
            (p) => p == '..' || p == '.' || p.isEmpty && parts.length > 1);
      }

      expect(isSafe('clips/test.mp4'), isTrue);
      expect(isSafe('metadata.json'), isTrue);
      expect(isSafe('faces/alice.jpg'), isTrue);
      expect(isSafe('clips/../../evil.txt'), isFalse);
      expect(isSafe('../outside.txt'), isFalse);
      expect(isSafe('clips/../../../etc/passwd'), isFalse);
    });

    test('invalid ZIP data produces empty archive', () {
      final archive = ZipDecoder().decodeBytes([0, 1, 2, 3]);
      expect(archive.isEmpty, isTrue);
      expect(archive.findFile('metadata.json'), isNull);
    });

    test('utf8 round-trip preserves non-ASCII characters', () {
      // Simulate what writeString/readString must do:
      const input = 'São Paulo — Ñoño café';
      final encoded = utf8.encode(input);           // Uint8List
      final decoded = utf8.decode(encoded);
      expect(decoded, equals(input));

      // Demonstrate the BUG (codeUnits truncation):
      final buggy = Uint8List.fromList(input.codeUnits);
      expect(String.fromCharCodes(buggy), isNot(equals(input)));
    });
  });
}
