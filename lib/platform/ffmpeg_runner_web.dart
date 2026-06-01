import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import '../models/clip.dart';
import 'file_storage.dart';

// ── JS interop bindings for @ffmpeg/ffmpeg v0.12 UMD (window.FFmpegWASM) ────

extension type _LoadConfig._(JSObject _) implements JSObject {
  external factory _LoadConfig({String coreURL, String wasmURL});
}

extension type _LogData._(JSObject _) implements JSObject {
  external String get message;
}

@JS('FFmpegWASM.FFmpeg')
extension type _FFmpegInstance._(JSObject _) implements JSObject {
  external factory _FFmpegInstance();
  external bool get loaded;
  external JSPromise load(_LoadConfig config);
  external JSPromise exec(JSArray<JSString> args);
  external JSPromise writeFile(String path, JSUint8Array data);
  external JSPromise readFile(String path);
  external JSPromise deleteFile(String path);
  external void on(String event, JSFunction handler);
  external void terminate();
}

// ── Singleton state ──────────────────────────────────────────────────────────

_FFmpegInstance? _ffmpeg;
bool _loaded = false;
bool _fontLoaded = false;
final _logBuf = StringBuffer();
String _lastLog = '';

void _handleLog(JSObject data) {
  final msg = (data as _LogData).message;
  _logBuf.writeln(msg);
}

// ── FfmpegRunner ─────────────────────────────────────────────────────────────

/// Web (ffmpeg.wasm v0.12) FFmpeg runner.
/// Each operation reads inputs from OPFS, processes via WASM, writes output to OPFS.
class FfmpegRunner {
  static const String fontPath = 'fonts/Roboto.ttf';

  /// Initialize the ffmpeg.wasm instance. Safe to call multiple times.
  static Future<void> initialize() async {
    if (_loaded) return;
    _ffmpeg = _FFmpegInstance();
    _ffmpeg!.on('log', _handleLog.toJS);
    await _ffmpeg!.load(_LoadConfig(
      coreURL: 'ffmpeg/ffmpeg-core.js',
      wasmURL: 'ffmpeg/ffmpeg-core.wasm',
    )).toDart;
    _loaded = true;
    await _loadFont();
  }

  static Future<void> _loadFont() async {
    if (_fontLoaded) return;
    try {
      final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bytes = data.buffer.asUint8List();
      await _write('fonts/Roboto.ttf', bytes);
      _fontLoaded = true;
    } catch (_) {
      // Font unavailable — drawtext will use default bitmap font
    }
  }

  // ── WASM FS helpers ─────────────────────────────────────────────────────

  static Future<void> _write(String name, Uint8List bytes) async {
    await _ffmpeg!.writeFile(name, bytes.toJS).toDart;
  }

  static Future<Uint8List?> _read(String name) async {
    try {
      final result = await _ffmpeg!.readFile(name).toDart;
      return (result as JSUint8Array).toDart;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _delete(String name) async {
    try {
      await _ffmpeg!.deleteFile(name).toDart;
    } catch (_) {}
  }

  /// Execute FFmpeg with args. Returns true on success (exit code 0).
  static Future<bool> _exec(List<String> args) async {
    _logBuf.clear();
    try {
      final jsArgs = args.map((a) => a.toJS).toList().toJS;
      final result = await _ffmpeg!.exec(jsArgs).toDart;
      final exitCode = (result as JSNumber).toDartInt;
      _lastLog = _logBuf.toString();
      return exitCode == 0;
    } catch (e) {
      _lastLog = _logBuf.toString();
      debugPrint('ffmpeg.wasm exec error: $e\nLog: $_lastLog');
      return false;
    }
  }

  /// Load input from OPFS into WASM FS. Returns wasm filename on success.
  static Future<Uint8List?> _fromOpfs(String opfsPath) async {
    return FileStorage.readBytes(opfsPath);
  }

  /// Write output bytes to OPFS path.
  static Future<void> _toOpfs(String opfsPath, Uint8List bytes) async {
    await FileStorage.writeBytes(opfsPath, bytes);
  }

  // ── Probe helpers ────────────────────────────────────────────────────────

  static Future<bool> _probeWithBytes(Uint8List bytes,
      Future<bool> Function(String log) parse) async {
    await _ensureInit();
    await _write('probe_in.mp4', bytes);
    // Run -i probe_in.mp4 — exits non-zero but stderr has media info
    await _exec(['-i', 'probe_in.mp4', '-f', 'null', '-']);
    final log = _lastLog;
    await _delete('probe_in.mp4');
    return parse(log);
  }

  static Future<void> _ensureInit() async {
    if (!_loaded) await initialize();
  }

  // ── Public API ───────────────────────────────────────────────────────────

  static Future<bool> hasAudioStream(String videoPath) async {
    await _ensureInit();
    final bytes = await _fromOpfs(videoPath);
    if (bytes == null) return false;
    return _probeWithBytes(bytes, (log) async {
      return log.contains('Audio:');
    });
  }

  static Future<double?> getVideoDuration(String videoPath) async {
    await _ensureInit();
    final bytes = await _fromOpfs(videoPath);
    if (bytes == null) return null;
    await _write('probe_dur.mp4', bytes);
    await _exec(['-i', 'probe_dur.mp4', '-f', 'null', '-']);
    final log = _lastLog;
    await _delete('probe_dur.mp4');
    return _parseDuration(log);
  }

  static double? _parseDuration(String log) {
    // Pattern: "Duration: HH:MM:SS.ms"
    final m = RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)').firstMatch(log);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final sec = double.parse(m.group(3)!);
    return h * 3600 + min * 60 + sec;
  }

  // Scale/pad filter common to most operations (portrait 1080×1920)
  static const _scaleFilter =
      'scale=iw*min(1080/iw\\,1920/ih):ih*min(1080/iw\\,1920/ih),'
      'pad=1080:1920:(1080-iw*min(1080/iw\\,1920/ih))/2:'
      '(1920-ih*min(1080/iw\\,1920/ih))/2,setsar=1';

  static Future<String?> photoToVideo(String imagePath, String outputPath,
      {double duration = 1.0}) async {
    await _ensureInit();
    final inBytes = await _fromOpfs(imagePath);
    if (inBytes == null) return null;
    await _write('photo_in.jpg', inBytes);
    final ok = await _exec([
      '-y', '-loop', '1', '-i', 'photo_in.jpg',
      '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23', '-preset', 'ultrafast',
      '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
      '-vf', 'scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1',
      '-t', '$duration',
      'photo_out.mp4',
    ]);
    await _delete('photo_in.jpg');
    if (!ok) return null;
    final outBytes = await _read('photo_out.mp4');
    await _delete('photo_out.mp4');
    if (outBytes == null) return null;
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  static Future<String?> extractSegment(
    String inputPath,
    String outputPath,
    double startSeconds, {
    double duration = 1.0,
  }) async {
    await _ensureInit();
    final inBytes = await _fromOpfs(inputPath);
    if (inBytes == null) return null;
    await _write('seg_in.mp4', inBytes);
    final ok = await _exec([
      '-y', '-ss', '$startSeconds', '-i', 'seg_in.mp4',
      '-t', '$duration',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23', '-preset', 'ultrafast',
      '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
      '-vf', _scaleFilter,
      'seg_out.mp4',
    ]);
    await _delete('seg_in.mp4');
    if (!ok) return null;
    final outBytes = await _read('seg_out.mp4');
    await _delete('seg_out.mp4');
    if (outBytes == null) return null;
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  static Future<String?> trimVideo(String inputPath, String outputPath,
      {double duration = 1.0}) async {
    await _ensureInit();
    final inBytes = await _fromOpfs(inputPath);
    if (inBytes == null) return null;
    await _write('trim_in.mp4', inBytes);
    final ok = await _exec([
      '-y', '-i', 'trim_in.mp4',
      '-t', '$duration',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23', '-preset', 'ultrafast',
      '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
      '-vf', _scaleFilter,
      'trim_out.mp4',
    ]);
    await _delete('trim_in.mp4');
    if (!ok) return null;
    final outBytes = await _read('trim_out.mp4');
    await _delete('trim_out.mp4');
    if (outBytes == null) return null;
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  static Future<String?> generateThumbnail(
      String videoPath, String outputPath) async {
    await _ensureInit();
    final inBytes = await _fromOpfs(videoPath);
    if (inBytes == null) return null;
    await _write('thumb_in.mp4', inBytes);
    final ok = await _exec([
      '-y', '-i', 'thumb_in.mp4',
      '-ss', '0.5', '-vframes', '1', '-q:v', '2',
      '-vf', 'scale=320:-1',
      'thumb_out.jpg',
    ]);
    await _delete('thumb_in.mp4');
    if (!ok) return null;
    final outBytes = await _read('thumb_out.jpg');
    await _delete('thumb_out.jpg');
    if (outBytes == null) return null;
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  static Future<String?> normalizeClip(
      String inputPath, String outputPath) async {
    await _ensureInit();
    final inBytes = await _fromOpfs(inputPath);
    if (inBytes == null) return null;
    await _write('norm_in.mp4', inBytes);

    // Probe for audio
    await _exec(['-i', 'norm_in.mp4', '-f', 'null', '-']);
    final hasAudio = _lastLog.contains('Audio:');
    final dur = _parseDuration(_lastLog);

    List<String> args;
    if (hasAudio) {
      args = [
        '-y', '-i', 'norm_in.mp4',
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23', '-preset', 'ultrafast',
        '-vf', _scaleFilter,
        '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
        'norm_out.mp4',
      ];
    } else {
      args = [
        '-y', '-i', 'norm_in.mp4',
        '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo',
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23', '-preset', 'ultrafast',
        '-vf', _scaleFilter,
        '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
        if (dur != null) ...['-t', '$dur'],
        'norm_out.mp4',
      ];
    }
    final ok = await _exec(args);
    await _delete('norm_in.mp4');
    if (!ok) return null;
    final outBytes = await _read('norm_out.mp4');
    await _delete('norm_out.mp4');
    if (outBytes == null) return null;
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  static Future<String?> addSilentAudio(
      String inputPath, String outputPath) async {
    await _ensureInit();
    final inBytes = await _fromOpfs(inputPath);
    if (inBytes == null) return null;
    await _write('silent_in.mp4', inBytes);
    await _exec(['-i', 'silent_in.mp4', '-f', 'null', '-']);
    final dur = _parseDuration(_lastLog);
    final args = [
      '-y', '-i', 'silent_in.mp4',
      '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo',
      '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k',
      if (dur != null) ...['-t', '$dur'],
      'silent_out.mp4',
    ];
    final ok = await _exec(args);
    await _delete('silent_in.mp4');
    if (!ok) return null;
    final outBytes = await _read('silent_out.mp4');
    await _delete('silent_out.mp4');
    if (outBytes == null) return null;
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  /// Concatenate multiple clips. Normalizes each one-at-a-time to avoid heap exhaustion.
  static Future<String?> concatenateClips(
    List<String> clipPaths,
    String outputPath, {
    void Function(double)? onProgress,
  }) async {
    await _ensureInit();
    if (clipPaths.isEmpty) return null;
    if (clipPaths.length == 1) {
      await FileStorage.copyFile(clipPaths.first, outputPath);
      return outputPath;
    }

    // Normalize each clip one at a time; keep normalized bytes in memory
    final normalizedBytes = <Uint8List>[];
    for (var i = 0; i < clipPaths.length; i++) {
      final bytes = await _fromOpfs(clipPaths[i]);
      if (bytes == null) continue;
      await _write('cn_in.mp4', bytes);
      // Probe
      await _exec(['-i', 'cn_in.mp4', '-f', 'null', '-']);
      final log = _lastLog;
      final hasAudio = log.contains('Audio:');
      final dur = _parseDuration(log);
      final args = hasAudio
          ? [
              '-y', '-i', 'cn_in.mp4',
              '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23', '-preset', 'ultrafast',
              '-vf', _scaleFilter,
              '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
              'cn_out.mp4',
            ]
          : [
              '-y', '-i', 'cn_in.mp4',
              '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo',
              '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23', '-preset', 'ultrafast',
              '-vf', _scaleFilter,
              '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
              if (dur != null) ...['-t', '$dur'],
              'cn_out.mp4',
            ];
      final ok = await _exec(args);
      await _delete('cn_in.mp4');
      if (ok) {
        final nb = await _read('cn_out.mp4');
        await _delete('cn_out.mp4');
        if (nb != null) normalizedBytes.add(nb);
      }
      onProgress?.call((i + 1) / clipPaths.length * 0.7);
    }

    if (normalizedBytes.isEmpty) return null;

    // Load all normalized clips into WASM FS
    final wasmNames = <String>[];
    for (var i = 0; i < normalizedBytes.length; i++) {
      final name = 'cc_$i.mp4';
      await _write(name, normalizedBytes[i]);
      wasmNames.add(name);
    }

    // Write concat list
    final concatContent = wasmNames.map((n) => "file '$n'").join('\n');
    await _write('concat.txt', Uint8List.fromList(utf8.encode(concatContent)));
    onProgress?.call(0.8);

    final ok = await _exec([
      '-y', '-f', 'concat', '-safe', '0', '-i', 'concat.txt',
      '-c:v', 'libx264', '-crf', '23', '-preset', 'ultrafast',
      '-c:a', 'aac', '-b:a', '128k',
      'cc_out.mp4',
    ]);

    await _delete('concat.txt');
    for (final n in wasmNames) {
      await _delete(n);
    }

    if (!ok) return null;
    final outBytes = await _read('cc_out.mp4');
    await _delete('cc_out.mp4');
    if (outBytes == null) return null;
    onProgress?.call(1.0);
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  static Future<String?> addDateOverlay(
    String inputPath,
    String outputPath,
    String dateText, {
    String? locationText,
    String position = 'bottom-left',
    int fontSize = 36,
    String fontPath = '',
  }) async {
    await _ensureInit();
    final inBytes = await _fromOpfs(inputPath);
    if (inBytes == null) return null;
    await _write('ov_in.mp4', inBytes);

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

    // Write text to WASM FS (avoid escaping issues)
    await _write('ov_text.txt',
        Uint8List.fromList(utf8.encode(overlayText)));

    final fp = _fontLoaded ? FfmpegRunner.fontPath : '';
    final fontSpec = fp.isNotEmpty ? "fontfile='$fp':" : '';
    final vf =
        "drawtext=${fontSpec}textfile='ov_text.txt':x=$x:y=$y:fontsize=$fontSize:fontcolor=white:borderw=3:bordercolor=black";

    bool ok = false;
    try {
      ok = await _exec([
        '-y', '-i', 'ov_in.mp4',
        '-vf', vf,
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23', '-preset', 'ultrafast',
        '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
        'ov_out.mp4',
      ]);
    } finally {
      await _delete('ov_in.mp4');
      await _delete('ov_text.txt');
    }
    if (!ok) return null;
    final outBytes = await _read('ov_out.mp4');
    await _delete('ov_out.mp4');
    if (outBytes == null) return null;
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  static Future<String?> addBackgroundMusic(
    String videoPath,
    String musicPath,
    String outputPath, {
    double musicVolume = 0.3,
    double originalVolume = 0.3,
  }) async {
    await _ensureInit();
    final vidBytes = await _fromOpfs(videoPath);
    final musBytes = await _fromOpfs(musicPath);
    if (vidBytes == null || musBytes == null) return null;
    await _write('bgm_vid.mp4', vidBytes);
    await _write('bgm_mus.mp3', musBytes);

    // Get duration
    await _exec(['-i', 'bgm_vid.mp4', '-f', 'null', '-']);
    final dur = _parseDuration(_lastLog);
    final dargs = dur != null ? ['-t', '$dur'] : <String>[];

    final ok = await _exec([
      '-y', '-i', 'bgm_vid.mp4', '-i', 'bgm_mus.mp3',
      '-filter_complex',
      '[0:a]volume=$originalVolume[a0];[1:a]volume=$musicVolume[a1];'
          '[a0][a1]amix=inputs=2:duration=longest:dropout_transition=2[aout]',
      '-map', '0:v', '-map', '[aout]',
      '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k',
      ...dargs,
      'bgm_out.mp4',
    ]);
    await _delete('bgm_vid.mp4');
    await _delete('bgm_mus.mp3');
    if (!ok) return null;
    final outBytes = await _read('bgm_out.mp4');
    await _delete('bgm_out.mp4');
    if (outBytes == null) return null;
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  static Future<String?> addMultipleAudioTracks(
    String videoPath,
    List<AudioSegment> segments,
    String outputPath, {
    double originalVolume = 0.3,
  }) async {
    await _ensureInit();
    if (segments.isEmpty) return null;
    final vidBytes = await _fromOpfs(videoPath);
    if (vidBytes == null) return null;
    await _write('mat_vid.mp4', vidBytes);

    // Get duration from probe
    await _exec(['-i', 'mat_vid.mp4', '-f', 'null', '-']);
    final dur = _parseDuration(_lastLog) ?? 60.0;
    final dargs = ['-t', '$dur'];

    final inputs = ['-y', '-i', 'mat_vid.mp4'];
    final loadedIndices = <int>[];
    for (var i = 0; i < segments.length; i++) {
      final segBytes = await _fromOpfs(segments[i].filePath);
      if (segBytes != null) {
        await _write('mat_seg_$i.mp3', segBytes);
        inputs.addAll(['-i', 'mat_seg_$i.mp3']);
        loadedIndices.add(i);
      }
    }

    final loadedSegments = loadedIndices.map((i) => segments[i]).toList();
    final filterGraph =
        _buildMultiTrackFilterGraph(loadedSegments, originalVolume, dur);
    final ok = await _exec([
      ...inputs,
      '-filter_complex', filterGraph,
      '-map', '0:v', '-map', '[aout]',
      '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k',
      ...dargs,
      'mat_out.mp4',
    ]);

    await _delete('mat_vid.mp4');
    for (final i in loadedIndices) {
      await _delete('mat_seg_$i.mp3');
    }
    if (!ok) return null;
    final outBytes = await _read('mat_out.mp4');
    await _delete('mat_out.mp4');
    if (outBytes == null) return null;
    await _toOpfs(outputPath, outBytes);
    return outputPath;
  }

  static Future<void> cancel() async {
    try {
      _ffmpeg?.terminate();
      _loaded = false;
      _fontLoaded = false;
      _ffmpeg = null;
    } catch (_) {}
  }
}

// Private copy of buildMultiTrackFilterGraph (public version in ffmpeg_service.dart).
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
