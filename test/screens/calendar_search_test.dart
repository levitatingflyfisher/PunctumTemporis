import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';

void main() {
  group('Calendar search/filter logic', () {
    final testClips = <String, List<Clip>>{
      '2026-01-01': [
        _makeClip('a', '2026-01-01',
            tags: ['morning'], location: 'Paris', faces: ['Alice']),
      ],
      '2026-01-02': [
        _makeClip('b', '2026-01-02',
            tags: ['evening', 'food'], location: 'London'),
      ],
      '2026-01-03': [
        _makeClip('c', '2026-01-03', tags: ['morning'], faces: ['Bob']),
      ],
      '2026-01-04': [
        _makeClip('d', '2026-01-04', tags: ['work']),
      ],
    };

    test('no filters returns all dates', () {
      final filterTags = <String>{};
      final filterLocations = <String>{};
      final filterPeople = <String>{};

      final hasActive = filterTags.isNotEmpty ||
          filterLocations.isNotEmpty ||
          filterPeople.isNotEmpty;
      expect(hasActive, isFalse);

      // When no filters, use all dates
      final dates = testClips.keys.toSet();
      expect(dates.length, 4);
    });

    test('tag filter returns matching dates', () {
      final filterTags = {'morning'};
      final result = <String>{};

      for (final entry in testClips.entries) {
        for (final clip in entry.value) {
          if (clip.tags.any((t) => filterTags.contains(t))) {
            result.add(entry.key);
            break;
          }
        }
      }

      expect(result, {'2026-01-01', '2026-01-03'});
    });

    test('location filter returns matching dates', () {
      final filterLocations = {'Paris'};
      final result = <String>{};

      for (final entry in testClips.entries) {
        for (final clip in entry.value) {
          if (clip.locationLabel != null &&
              filterLocations.contains(clip.locationLabel)) {
            result.add(entry.key);
            break;
          }
        }
      }

      expect(result, {'2026-01-01'});
    });

    test('people filter returns matching dates', () {
      final filterPeople = {'Bob'};
      final result = <String>{};

      for (final entry in testClips.entries) {
        for (final clip in entry.value) {
          if (clip.detectedFaces.any((f) => filterPeople.contains(f))) {
            result.add(entry.key);
            break;
          }
        }
      }

      expect(result, {'2026-01-03'});
    });

    test('combined filters use AND logic', () {
      final filterTags = {'morning'};
      final filterPeople = {'Alice'};
      final result = <String>{};

      for (final entry in testClips.entries) {
        for (final clip in entry.value) {
          bool matches = true;
          if (filterTags.isNotEmpty) {
            matches = matches && clip.tags.any((t) => filterTags.contains(t));
          }
          if (filterPeople.isNotEmpty) {
            matches = matches &&
                clip.detectedFaces.any((f) => filterPeople.contains(f));
          }
          if (matches) {
            result.add(entry.key);
            break;
          }
        }
      }

      // Only 2026-01-01 has both 'morning' tag AND 'Alice' face
      expect(result, {'2026-01-01'});
    });

    test('empty filter set is not active', () {
      final tags = <String>{};
      final locations = <String>{};
      final people = <String>{};

      final hasActive =
          tags.isNotEmpty || locations.isNotEmpty || people.isNotEmpty;
      expect(hasActive, isFalse);
    });

    test('dimming logic: non-matching dates are dimmed', () {
      final highlightedDates = {'2026-01-01', '2026-01-03'};
      final allDates = ['2026-01-01', '2026-01-02', '2026-01-03', '2026-01-04'];

      final dimmed =
          allDates.where((d) => !highlightedDates.contains(d)).toList();
      expect(dimmed, ['2026-01-02', '2026-01-04']);
    });
  });
}

Clip _makeClip(
  String id,
  String date, {
  List<String> tags = const [],
  String? location,
  List<String> faces = const [],
}) {
  return Clip(
    id: id,
    date: date,
    filePath: '/fake/$id.mp4',
    type: ClipType.video,
    createdAt: DateTime.parse(date),
    duration: 1.0,
    tags: tags,
    locationLabel: location,
    detectedFaces: faces,
  );
}
