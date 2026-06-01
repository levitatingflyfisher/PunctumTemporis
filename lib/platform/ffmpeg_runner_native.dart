import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clip.dart';

/// Native (Android) FFmpeg runner — thin static wrappers around FFmpegKit.
/// All paths are real filesystem paths. Temp files use the system temp dir.
class FfmpegRunner {
  static Future<void> initialize() async {} // no-op on native

  static String get fontPath => '/system/fonts/Roboto-Regular.ttf';

  // ── Internal helpers ─────────────────────────────────────────────────────

  static Future<String> _tmpDir() async {
    return (await getTemporaryDirectory()).path;
  }

  static Future<bool> _run(String command) async {
    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final logs = await session.getAllLogsAsString();
      debugPrint('FFmpegKit failed: $logs');
      return false;
    }
    return true;
  }

  // ── Public API ───────────────────────────────────────────────────────────

  static Future<String?> photoToVideo(String imagePath, String outputPath,
      {double duration = 1.0}) async {
    final command = '-y -loop 1 -i "$imagePath" '
        '-f lavfi -i anullsrc=r=44100:cl=stereo '
        '-c:v libx264 -pix_fmt yuv420p -r 30 -crf 23 -preset fast '
        '-c:a aac -ar 44100 -ac 2 -b:a 128k '
        '-vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1" '
        '-t $duration '
        '"$outputPath"';
    return await _run(command) ? outputPath : null;
  }

  static Future<String?> extractSegment(
    String inputPath,
    String outputPath,
    double startSeconds, {
    double duration = 1.0,
  }) async {
    final command = '-y -ss $startSeconds -i "$inputPath" '
        '-t $duration -c:v libx264 -pix_fmt yuv420p -r 30 -crf 23 -preset fast '
        '-c:a aac -ar 44100 -ac 2 -b:a 128k '
        '-vf "scale=iw*min(1080/iw\\,1920/ih):ih*min(1080/iw\\,1920/ih),pad=1080:1920:(1080-iw*min(1080/iw\\,1920/ih))/2:(1920-ih*min(1080/iw\\,1920/ih))/2,setsar=1" '
        '"$outputPath"';
    return await _run(command) ? outputPath : null;
  }

  static Future<String?> trimVideo(String inputPath, String outputPath,
      {double duration = 1.0}) async {
    final command = '-y -i "$inputPath" '
        '-t $duration -c:v libx264 -pix_fmt yuv420p -r 30 -crf 23 -preset fast '
        '-c:a aac -ar 44100 -ac 2 -b:a 128k '
        '-vf "scale=iw*min(1080/iw\\,1920/ih):ih*min(1080/iw\\,1920/ih),pad=1080:1920:(1080-iw*min(1080/iw\\,1920/ih))/2:(1920-ih*min(1080/iw\\,1920/ih))/2,setsar=1" '
        '"$outputPath"';
    return await _run(command) ? outputPath : null;
  }

  static Future<String?> generateThumbnail(
      String videoPath, String outputPath) async {
    final command = '-y -i "$videoPath" '
        '-ss 0.5 -vframes 1 -q:v 2 '
        '-vf "scale=320:-1" '
        '"$outputPath"';
    return await _run(command) ? outputPath : null;
  }

  static Future<bool> hasAudioStream(String videoPath) async {
    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info = session.getMediaInformation();
    if (info == null) return false;
    for (final stream in info.getStreams()) {
      if (stream.getType() == 'audio') return true;
    }
    return false;
  }

  static Future<double?> getVideoDuration(String videoPath) async {
    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info = session.getMediaInformation();
    if (info != null) {
      final d = info.getDuration();
      if (d != null) return double.tryParse(d);
    }
    return null;
  }

  static Future<String?> normalizeClip(
      String inputPath, String outputPath) async {
    final hasAudio = await hasAudioStream(inputPath);
    final String command;
    if (hasAudio) {
      command = '-y -i "$inputPath" '
          '-c:v libx264 -pix_fmt yuv420p -r 30 -crf 23 -preset fast '
          '-vf "scale=iw*min(1080/iw\\,1920/ih):ih*min(1080/iw\\,1920/ih),pad=1080:1920:(1080-iw*min(1080/iw\\,1920/ih))/2:(1920-ih*min(1080/iw\\,1920/ih))/2,setsar=1" '
          '-c:a aac -ar 44100 -ac 2 -b:a 128k '
          '"$outputPath"';
    } else {
      final d = await getVideoDuration(inputPath);
      final df = d != null ? '-t $d ' : '';
      command = '-y -i "$inputPath" '
          '-f lavfi -i anullsrc=r=44100:cl=stereo '
          '-c:v libx264 -pix_fmt yuv420p -r 30 -crf 23 -preset fast '
          '-vf "scale=iw*min(1080/iw\\,1920/ih):ih*min(1080/iw\\,1920/ih),pad=1080:1920:(1080-iw*min(1080/iw\\,1920/ih))/2:(1920-ih*min(1080/iw\\,1920/ih))/2,setsar=1" '
          '-c:a aac -ar 44100 -ac 2 -b:a 128k $df'
          '"$outputPath"';
    }
    return await _run(command) ? outputPath : null;
  }

  static Future<String?> addSilentAudio(
      String inputPath, String outputPath) async {
    final d = await getVideoDuration(inputPath);
    final df = d != null ? '-t $d ' : '';
    final command = '-y -i "$inputPath" '
        '-f lavfi -i anullsrc=r=44100:cl=stereo '
        '-c:v copy -c:a aac -b:a 128k $df'
        '"$outputPath"';
    return await _run(command) ? outputPath : null;
  }

  static Future<String?> concatenateClips(
    List<String> clipPaths,
    String outputPath, {
    void Function(double)? onProgress,
  }) async {
    if (clipPaths.isEmpty) return null;
    if (clipPaths.length == 1) {
      await File(clipPaths.first).copy(outputPath);
      return outputPath;
    }

    final tmpDir = await _tmpDir();
    final normalizedPaths = <String>[];
    final tempToClean = <String>[];

    for (var i = 0; i < clipPaths.length; i++) {
      final normPath = '$tmpDir/normalized_$i.mp4';
      final result = await normalizeClip(clipPaths[i], normPath);
      if (result != null) {
        normalizedPaths.add(result);
        tempToClean.add(result);
      } else {
        normalizedPaths.add(clipPaths[i]);
      }
    }

    final concatFile = File('$tmpDir/concat_list.txt');
    await concatFile.writeAsString(
        normalizedPaths.map((p) => "file '$p'").join('\n'));

    if (onProgress != null) {
      FFmpegKitConfig.enableStatisticsCallback((statistics) {
        final time = statistics.getTime();
        if (time > 0) {
          onProgress((time / 1000 / clipPaths.length.toDouble()).clamp(0.0, 1.0));
        }
      });
    }

    final command = '-y -f concat -safe 0 -i "${concatFile.path}" '
        '-c:v libx264 -crf 23 -preset fast '
        '-c:a aac -b:a 128k '
        '"$outputPath"';

    final ok = await _run(command);
    await concatFile.delete();
    for (final p in tempToClean) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    return ok ? outputPath : null;
  }

  static Future<String?> addDateOverlay(
    String inputPath,
    String outputPath,
    String dateText, {
    String? locationText,
    String position = 'bottom-left',
    int fontSize = 36,
    String fontPath = '/system/fonts/Roboto-Regular.ttf',
  }) async {
    String x, y;
    switch (position) {
      case 'top-left':
        x = '30';
        y = '30';
        break;
      case 'top-right':
        x = 'w-tw-30';
        y = '30';
        break;
      case 'bottom-right':
        x = 'w-tw-30';
        y = 'h-th-30';
        break;
      case 'bottom-left':
      default:
        x = '30';
        y = 'h-th-30';
    }

    final overlayText = locationText != null && locationText.isNotEmpty
        ? '$dateText : ${locationText.toUpperCase()}'
        : dateText;

    final tmpDir = await _tmpDir();
    final textFile =
        File('$tmpDir/overlay_text_${DateTime.now().millisecondsSinceEpoch}.txt');
    await textFile.writeAsString(overlayText);

    final fp = fontPath.isEmpty ? FfmpegRunner.fontPath : fontPath;
    final command = '-y -i "$inputPath" '
        '-vf "drawtext=fontfile=\'$fp\':textfile=\'${textFile.path}\':x=$x:y=$y:fontsize=$fontSize:fontcolor=white:borderw=3:bordercolor=black" '
        '-c:v libx264 -pix_fmt yuv420p -r 30 -crf 23 -preset fast '
        '-c:a aac -ar 44100 -ac 2 -b:a 128k '
        '"$outputPath"';

    final ok = await _run(command);
    try {
      await textFile.delete();
    } catch (_) {}
    return ok ? outputPath : null;
  }

  static Future<String?> addBackgroundMusic(
    String videoPath,
    String musicPath,
    String outputPath, {
    double musicVolume = 0.3,
    double originalVolume = 0.3,
  }) async {
    final d = await getVideoDuration(videoPath);
    final df = d != null ? '-t $d ' : '';
    final command = '-y -i "$videoPath" -i "$musicPath" '
        '-filter_complex "[0:a]volume=$originalVolume[a0];[1:a]volume=$musicVolume[a1];'
        '[a0][a1]amix=inputs=2:duration=longest:dropout_transition=2[aout]" '
        '-map 0:v -map "[aout]" '
        '-c:v copy -c:a aac -b:a 128k $df'
        '"$outputPath"';
    return await _run(command) ? outputPath : null;
  }

  static Future<String?> addMultipleAudioTracks(
    String videoPath,
    List<AudioSegment> segments,
    String outputPath, {
    double originalVolume = 0.3,
  }) async {
    if (segments.isEmpty) return null;
    final d = await getVideoDuration(videoPath);
    final vDur = d ?? 60.0;
    final df = d != null ? '-t $d ' : '';
    final inputs = StringBuffer('-y -i "$videoPath" ');
    for (final seg in segments) {
      inputs.write('-i "${seg.filePath}" ');
    }
    final filterGraph = _buildMultiTrackFilterGraph(segments, originalVolume, vDur);
    final command = '${inputs}-filter_complex "$filterGraph" '
        '-map 0:v -map "[aout]" '
        '-c:v copy -c:a aac -b:a 128k $df'
        '"$outputPath"';
    return await _run(command) ? outputPath : null;
  }

  static Future<void> cancel() async {
    await FFmpegKit.cancel();
  }
}

// Private copy — the public version lives in ffmpeg_service.dart for tests.
String _buildMultiTrackFilterGraph(
  List<AudioSegment> segments,
  double originalVolume,
  double videoDuration,
) {
  final f = StringBuffer();
  f.write('[0:a]volume=$originalVolume[orig];');
  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    final delayMs = (seg.startTimeInCompilation * 1000).toInt();
    final endTime = seg.audioOffset +
        (seg.duration ?? (videoDuration - seg.startTimeInCompilation));
    f.write('[${i + 1}:a]');
    if (seg.audioOffset > 0) {
      f.write('atrim=start=${seg.audioOffset}:end=$endTime,asetpts=PTS-STARTPTS,');
    } else {
      f.write('atrim=end=$endTime,asetpts=PTS-STARTPTS,');
    }
    if (delayMs > 0) f.write('adelay=$delayMs|$delayMs,');
    f.write('volume=${seg.volume}[a$i];');
  }
  f.write('[orig]');
  for (var i = 0; i < segments.length; i++) {
    f.write('[a$i]');
  }
  f.write('amix=inputs=${segments.length + 1}:duration=longest:dropout_transition=2[aout]');
  return f.toString();
}
