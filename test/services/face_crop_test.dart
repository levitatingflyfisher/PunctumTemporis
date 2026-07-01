import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:one_second_a_day/services/face_crop.dart';

void main() {
  // A solid 100x80 source image encoded as JPEG.
  Uint8List sourceJpg() {
    final im = img.Image(width: 100, height: 80);
    img.fill(im, color: img.ColorRgb8(120, 120, 120));
    return img.encodeJpg(im);
  }

  test('crops to the bounding box dimensions (not the whole frame)', () {
    final out = cropFaceJpg(sourceJpg(), const Rect.fromLTWH(10, 20, 30, 40));
    expect(out, isNotNull);
    final decoded = img.decodeImage(out!)!;
    expect(decoded.width, 30);
    expect(decoded.height, 40);
  });

  test('clamps a box that extends past the image bounds', () {
    // ML Kit boxes can spill past the edges; the crop must stay inside.
    final out = cropFaceJpg(sourceJpg(), const Rect.fromLTWH(90, 70, 50, 50));
    final decoded = img.decodeImage(out!)!;
    expect(decoded.width, 10); // x=90 → 100-90
    expect(decoded.height, 10); // y=70 → 80-70
  });

  test('returns null for undecodable bytes so the caller can fall back', () {
    expect(
      cropFaceJpg(Uint8List.fromList([1, 2, 3]), const Rect.fromLTWH(0, 0, 5, 5)),
      isNull,
    );
  });
}
