import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

// Stub data types — mirrors face_service_impl.dart public API
class FaceDetectionResult {
  final List<double> embedding;
  final ui.Rect boundingBox;
  FaceDetectionResult({required this.embedding, required this.boundingBox});
}

typedef FaceMatchResult = ({String name, double score});

/// Web stub: face recognition is not available on web.
/// All methods return empty results immediately.
class FaceService {
  static FaceService? _instance;

  FaceService._();

  static FaceService get instance {
    _instance ??= FaceService._();
    return _instance!;
  }

  Future<void> initialize() async {}

  bool get isAvailable => false;
  String? get initError => 'Face recognition is not available on web.';

  Future<List<FaceDetectionResult>> detectAndEmbed(String imagePath) async => [];

  double cosineSimilarity(List<double> a, List<double> b) => 0;

  FaceMatchResult? findBestMatch(
    List<double> embedding,
    Map<String, List<List<double>>> knownPeople, {
    double threshold = 0.6,
  }) => null;

  void dispose() {
    _instance = null;
  }
}
