import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class FaceDetectionResult {
  final List<double> embedding;
  final Rect boundingBox;

  FaceDetectionResult({required this.embedding, required this.boundingBox});
}

/// Result of finding a best match: person name + similarity score.
typedef FaceMatchResult = ({String name, double score});

class FaceService {
  static FaceService? _instance;

  final FaceDetector _faceDetector;
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  String? _initError;

  FaceService._()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.accurate,
            enableLandmarks: true,
            minFaceSize: 0.15,
          ),
        );

  static FaceService get instance {
    _instance ??= FaceService._();
    return _instance!;
  }

  /// Load the MobileFaceNet TFLite model
  Future<void> initialize() async {
    if (_isModelLoaded) return;

    // Try multiple asset paths — path resolution varies across tflite_flutter versions
    final paths = [
      'models/mobilefacenet.tflite',
      'assets/models/mobilefacenet.tflite',
    ];

    for (final path in paths) {
      try {
        _interpreter = await Interpreter.fromAsset(path);
        _isModelLoaded = true;
        _initError = null;
        debugPrint('Face model loaded from: $path');
        return;
      } catch (e) {
        _initError = 'Failed to load face model from $path: $e';
        debugPrint(_initError);
      }
    }
  }

  bool get isAvailable => _isModelLoaded;
  String? get initError => _initError;

  /// Detect faces in an image and generate embeddings for each
  Future<List<FaceDetectionResult>> detectAndEmbed(String imagePath) async {
    if (!_isModelLoaded) return [];

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) return [];

      // Read image bytes for cropping
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final results = <FaceDetectionResult>[];

      for (final face in faces) {
        final embedding = await _generateEmbedding(image, face.boundingBox);
        if (embedding != null) {
          results.add(FaceDetectionResult(
            embedding: embedding,
            boundingBox: Rect.fromLTWH(
              face.boundingBox.left,
              face.boundingBox.top,
              face.boundingBox.width,
              face.boundingBox.height,
            ),
          ));
        }
      }

      image.dispose();
      return results;
    } catch (e) {
      debugPrint('Face detection failed: $e');
      return [];
    }
  }

  /// Generate a 192-dim embedding from a cropped face region
  Future<List<double>?> _generateEmbedding(
      ui.Image image, Rect boundingBox) async {
    if (_interpreter == null) return null;

    try {
      // Clamp bounding box to image dimensions
      final left = boundingBox.left.clamp(0, image.width.toDouble()).toInt();
      final top = boundingBox.top.clamp(0, image.height.toDouble()).toInt();
      final right = boundingBox.right.clamp(0, image.width.toDouble()).toInt();
      final bottom =
          boundingBox.bottom.clamp(0, image.height.toDouble()).toInt();
      final width = right - left;
      final height = bottom - top;

      if (width <= 0 || height <= 0) return null;

      // Get raw pixel data from the image
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      // Crop and resize to 112x112 for MobileFaceNet
      final input = Float32List(1 * 112 * 112 * 3);
      final stride = image.width * 4; // RGBA bytes per row

      for (var y = 0; y < 112; y++) {
        for (var x = 0; x < 112; x++) {
          // Map to source coordinates
          final srcX = left + (x * width / 112).round();
          final srcY = top + (y * height / 112).round();

          final clampedX = srcX.clamp(0, image.width - 1);
          final clampedY = srcY.clamp(0, image.height - 1);

          final offset = clampedY * stride + clampedX * 4;

          // Normalize to [-1, 1] range for MobileFaceNet
          final idx = (y * 112 + x) * 3;
          input[idx] = (byteData.getUint8(offset) / 127.5) - 1.0; // R
          input[idx + 1] = (byteData.getUint8(offset + 1) / 127.5) - 1.0; // G
          input[idx + 2] = (byteData.getUint8(offset + 2) / 127.5) - 1.0; // B
        }
      }

      // Reshape for model: [1, 112, 112, 3]
      final inputTensor = input.reshape([1, 112, 112, 3]);
      final output = List.filled(1 * 192, 0.0).reshape([1, 192]);

      _interpreter!.run(inputTensor, output);

      return (output[0] as List).cast<double>();
    } catch (e) {
      debugPrint('Embedding generation failed: $e');
      return null;
    }
  }

  /// Cosine similarity between two embedding vectors
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;

    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 0;

    return dotProduct / denominator;
  }

  /// Find best matching person from known embeddings.
  /// Returns ({name, score}) if similarity > threshold, null otherwise.
  FaceMatchResult? findBestMatch(
    List<double> embedding,
    Map<String, List<List<double>>> knownPeople, {
    double threshold = 0.6,
  }) {
    String? bestName;
    double bestScore = threshold;

    for (final entry in knownPeople.entries) {
      for (final refEmbedding in entry.value) {
        final score = cosineSimilarity(embedding, refEmbedding);
        if (score > bestScore) {
          bestScore = score;
          bestName = entry.key;
        }
      }
    }

    if (bestName == null) return null;
    return (name: bestName, score: bestScore);
  }

  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
    _instance = null;
  }
}
