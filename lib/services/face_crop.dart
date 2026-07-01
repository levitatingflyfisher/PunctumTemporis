import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

/// Crops [sourceBytes] to [box] (pixel coordinates in the source image) and
/// re-encodes as JPEG.
///
/// The box is clamped to the image bounds — ML Kit face boxes routinely extend
/// past the edges. Returns null if the bytes can't be decoded, so the caller
/// can fall back to copying the whole image rather than losing the face.
Uint8List? cropFaceJpg(Uint8List sourceBytes, Rect box) {
  try {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return null;
    final x = box.left.round().clamp(0, decoded.width - 1);
    final y = box.top.round().clamp(0, decoded.height - 1);
    final w = box.width.round().clamp(1, decoded.width - x);
    final h = box.height.round().clamp(1, decoded.height - y);
    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    return img.encodeJpg(cropped);
  } catch (_) {
    // Malformed/undecodable bytes (decodeImage can throw, not just return
    // null) — let the caller fall back to copying the whole image.
    return null;
  }
}
