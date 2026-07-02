import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Prevent Google Fonts HTTP calls in tests
  setUp(() {
  });

  group('Trim UI logic', () {
    test('trim start clamps to valid range', () {
      const videoDuration = 5.0;
      const trimDuration = 1.0;

      // Max trim start should be videoDuration - trimDuration
      final maxStart = (videoDuration - trimDuration).clamp(0.0, videoDuration);
      expect(maxStart, 4.0);

      // At max start, trim end is exactly video duration
      final trimEnd = maxStart + trimDuration;
      expect(trimEnd, 5.0);
    });

    test('trim duration clamps to available space', () {
      const videoDuration = 3.0;
      const trimStart = 1.5;

      final maxDuration = (videoDuration - trimStart).clamp(0.5, videoDuration);
      expect(maxDuration, 1.5);
    });

    test('trim presets filter by video duration', () {
      const videoDuration = 2.0;
      final presets = [0.5, 1.0, 1.5, 2.0, 3.0];
      final validPresets = presets.where((d) => d <= videoDuration).toList();

      expect(validPresets, [0.5, 1.0, 1.5, 2.0]);
      expect(validPresets, isNot(contains(3.0)));
    });

    test('very short video allows minimum trim', () {
      const videoDuration = 0.5;
      final presets = [0.5, 1.0, 1.5, 2.0, 3.0];
      final validPresets = presets.where((d) => d <= videoDuration).toList();

      expect(validPresets, [0.5]);
    });
  });
}
