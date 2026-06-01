import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/services/ffmpeg_service.dart';

void main() {
  group('buildMultiTrackFilterGraph', () {
    test('single segment, no offset, no explicit duration', () {
      final segments = [
        AudioSegment(
          filePath: '/audio/track1.mp3',
          fileName: 'track1.mp3',
          startTimeInCompilation: 0,
          audioOffset: 0,
          volume: 0.5,
        ),
      ];

      final graph = buildMultiTrackFilterGraph(segments, 0.3, 30.0);

      // Should have original volume filter
      expect(graph, contains('[0:a]volume=0.3[orig]'));
      // Should trim to end=30.0 (videoDuration - startTime 0 = 30, + audioOffset 0 = 30)
      expect(graph, contains('[1:a]atrim=end=30.0,asetpts=PTS-STARTPTS,'));
      // No adelay since startTimeInCompilation is 0
      expect(graph, isNot(contains('adelay')));
      // Should have volume filter
      expect(graph, contains('volume=0.5'));
      // Should end with amix
      expect(
          graph,
          contains(
              '[orig][a0]amix=inputs=2:duration=longest:dropout_transition=2[aout]'));
    });

    test('two segments with different start times', () {
      final segments = [
        AudioSegment(
          filePath: '/audio/track1.mp3',
          fileName: 'track1.mp3',
          startTimeInCompilation: 0,
          audioOffset: 0,
          volume: 0.3,
        ),
        AudioSegment(
          filePath: '/audio/track2.mp3',
          fileName: 'track2.mp3',
          startTimeInCompilation: 10.0,
          audioOffset: 0,
          volume: 0.5,
        ),
      ];

      final graph = buildMultiTrackFilterGraph(segments, 0.3, 30.0);

      // First segment: no delay
      expect(graph,
          isNot(contains('[1:a]atrim=end=30.0,asetpts=PTS-STARTPTS,adelay')));
      // Second segment: delay of 10000ms
      expect(graph, contains('adelay=10000|10000'));
      // Second segment: atrim end = 0 + (30 - 10) = 20
      expect(graph, contains('[2:a]atrim=end=20.0,asetpts=PTS-STARTPTS,'));
      // Mix 3 inputs (orig + 2 segments)
      expect(graph, contains('amix=inputs=3'));
    });

    test('segment with audioOffset produces atrim with start and end', () {
      final segments = [
        AudioSegment(
          filePath: '/audio/track1.mp3',
          fileName: 'track1.mp3',
          startTimeInCompilation: 5.0,
          audioOffset: 15.0,
          volume: 0.4,
        ),
      ];

      final graph = buildMultiTrackFilterGraph(segments, 0.3, 30.0);

      // atrim start=15.0, end = 15.0 + (30.0 - 5.0) = 40.0
      expect(graph, contains('atrim=start=15.0:end=40.0,asetpts=PTS-STARTPTS'));
      // delay of 5000ms
      expect(graph, contains('adelay=5000|5000'));
    });

    test('segment with explicit duration uses it for end time', () {
      final segments = [
        AudioSegment(
          filePath: '/audio/track1.mp3',
          fileName: 'track1.mp3',
          startTimeInCompilation: 5.0,
          audioOffset: 10.0,
          duration: 8.0,
          volume: 0.6,
        ),
      ];

      final graph = buildMultiTrackFilterGraph(segments, 0.3, 30.0);

      // end = audioOffset + duration = 10.0 + 8.0 = 18.0
      expect(graph, contains('atrim=start=10.0:end=18.0,asetpts=PTS-STARTPTS'));
    });

    test('segment with zero audioOffset and explicit duration', () {
      final segments = [
        AudioSegment(
          filePath: '/audio/track1.mp3',
          fileName: 'track1.mp3',
          startTimeInCompilation: 0,
          audioOffset: 0,
          duration: 15.0,
          volume: 0.3,
        ),
      ];

      final graph = buildMultiTrackFilterGraph(segments, 0.3, 30.0);

      // end = 0 + 15.0 = 15.0, no start= since audioOffset is 0
      expect(graph, contains('atrim=end=15.0,asetpts=PTS-STARTPTS'));
      expect(graph, isNot(contains('atrim=start=0')));
    });
  });
}
