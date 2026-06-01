// Platform twin: FFmpegKit on Android, ffmpeg.wasm on web.
export 'ffmpeg_runner_native.dart'
    if (dart.library.js_interop) 'ffmpeg_runner_web.dart';
