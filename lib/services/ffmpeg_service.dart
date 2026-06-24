import '../models/clip.dart';
import '../platform/ffmpeg_runner.dart';

/// Service for video processing — delegates to FfmpegRunner (platform-specific).
class FFmpegService {
  Future<String?> photoToVideo(String imagePath, String outputPath,
          {double duration = 1.0}) =>
      FfmpegRunner.photoToVideo(imagePath, outputPath, duration: duration);

  Future<String?> extractSegment(
    String inputPath,
    String outputPath,
    double startSeconds, {
    double duration = 1.0,
  }) =>
      FfmpegRunner.extractSegment(inputPath, outputPath, startSeconds,
          duration: duration);

  Future<String?> trimVideo(String inputPath, String outputPath,
          {double duration = 1.0}) =>
      FfmpegRunner.trimVideo(inputPath, outputPath, duration: duration);

  Future<String?> generateThumbnail(String videoPath, String outputPath) =>
      FfmpegRunner.generateThumbnail(videoPath, outputPath);

  Future<bool> hasAudioStream(String videoPath) =>
      FfmpegRunner.hasAudioStream(videoPath);

  Future<String?> normalizeClip(String inputPath, String outputPath) =>
      FfmpegRunner.normalizeClip(inputPath, outputPath);

  Future<String?> addSilentAudio(String inputPath, String outputPath) =>
      FfmpegRunner.addSilentAudio(inputPath, outputPath);

  Future<double?> getVideoDuration(String videoPath) =>
      FfmpegRunner.getVideoDuration(videoPath);

  Future<String?> concatenateClips(
    List<String> clipPaths,
    String outputPath, {
    void Function(double)? onProgress,
  }) =>
      FfmpegRunner.concatenateClips(clipPaths, outputPath,
          onProgress: onProgress);

  Future<String?> addDateOverlay(
    String inputPath,
    String outputPath,
    String dateText, {
    String? locationText,
    String position = 'bottom-left',
    int fontSize = 36,
    String fontPath = '',
  }) =>
      FfmpegRunner.addDateOverlay(inputPath, outputPath, dateText,
          locationText: locationText,
          position: position,
          fontSize: fontSize,
          fontPath: fontPath);

  Future<String?> addBackgroundMusic(
    String videoPath,
    String musicPath,
    String outputPath, {
    double musicVolume = 0.3,
    double originalVolume = 0.3,
  }) =>
      FfmpegRunner.addBackgroundMusic(videoPath, musicPath, outputPath,
          musicVolume: musicVolume, originalVolume: originalVolume);

  Future<String?> addMultipleAudioTracks(
    String videoPath,
    List<AudioSegment> segments,
    String outputPath, {
    double originalVolume = 0.3,
  }) =>
      FfmpegRunner.addMultipleAudioTracks(videoPath, segments, outputPath,
          originalVolume: originalVolume);

  Future<void> cancel() => FfmpegRunner.cancel();
}

/// Build the filter_complex graph for multi-track audio mixing.
/// Pure function — kept here for testability (imported by ffmpeg_service_test.dart).
String buildMultiTrackFilterGraph(
  List<AudioSegment> segments,
  double originalVolume,
  double videoDuration,
) {
  final filters = StringBuffer();
  filters.write('[0:a]volume=$originalVolume[orig];');

  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    final inputIdx = i + 1;
    final delayMs = (seg.startTimeInCompilation * 1000).toInt();
    filters.write('[${inputIdx}:a]');
    final endTime = seg.audioOffset +
        (seg.duration ?? (videoDuration - seg.startTimeInCompilation));
    if (seg.audioOffset > 0) {
      filters.write(
          'atrim=start=${seg.audioOffset}:end=$endTime,asetpts=PTS-STARTPTS,');
    } else {
      filters.write('atrim=end=$endTime,asetpts=PTS-STARTPTS,');
    }
    if (delayMs > 0) {
      filters.write('adelay=$delayMs|$delayMs,');
    }
    filters.write('volume=${seg.volume}');
    filters.write('[a${i}];');
  }

  filters.write('[orig]');
  for (var i = 0; i < segments.length; i++) {
    filters.write('[a${i}]');
  }
  final totalInputs = segments.length + 1;
  filters.write(
      'amix=inputs=$totalInputs:duration=longest:dropout_transition=2[aout]');
  return filters.toString();
}
