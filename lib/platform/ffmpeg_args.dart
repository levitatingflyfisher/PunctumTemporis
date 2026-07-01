/// Pure FFmpeg argv builders — no dart:io, no plugin imports, fully unit
/// tested (test/services/ffmpeg_args_test.dart).
///
/// Why these exist: the native runner used to interpolate paths and overlay
/// text into ONE command string with double-quoted values and hand it to
/// `FFmpegKit.execute(String)`, whose tokenizer re-parses the quoting — so a
/// `"` (or backslash) inside a clip path closed the quoted token and the
/// remainder became injected ffmpeg argv. Building a `List<String>` for
/// `FFmpegKit.executeWithArguments` removes that parsing step entirely: each
/// path is one discrete argv element and no shell-style quoting exists to
/// break out of. (Mirrors the `buildMultiTrackFilterGraph` "pure seam for
/// testability" pattern in ffmpeg_service.dart.)
library;

/// Escapes a literal text value for ffmpeg's drawtext filter.
///
/// drawtext applies its own text expansion to the value (whether it arrives
/// via `text=` or a `textfile=`): `\X` expands to `X`, `%{...}` expands to
/// clip metadata, `:` ends an option and `'` quotes when inline. Escaping
/// the four drawtext-special characters `\ : ' %` with a backslash makes any
/// user-supplied overlay text (date + location) render literally instead of
/// being interpreted.
String escapeDrawtextText(String text) {
  return text
      .replaceAll('\\', r'\\') // first, so later escapes aren't re-escaped
      .replaceAll(':', r'\:')
      .replaceAll("'", r"\'")
      .replaceAll('%', r'\%');
}

/// One line of an ffmpeg concat-demuxer list file for [path].
///
/// The path is single-quoted; an embedded `'` is emitted as the `'\''`
/// idiom (close the quote, escaped quote, reopen), so a quote inside a clip
/// path can never terminate the token and smuggle further concat directives
/// into the list.
String concatListEntry(String path) {
  return "file '${path.replaceAll("'", r"'\''")}'";
}

/// Argv for the date/location drawtext overlay pass — the exact argument
/// order of the legacy interpolated command, minus its quoting.
///
/// The overlay text itself travels in a temp [textFilePath] (written by the
/// caller, content escaped via [escapeDrawtextText]); only app-controlled
/// paths appear inside the filter expression.
List<String> buildDateOverlayArgs({
  required String inputPath,
  required String outputPath,
  required String fontPath,
  required String textFilePath,
  required String x,
  required String y,
  required int fontSize,
}) {
  return [
    '-y',
    '-i',
    inputPath,
    '-vf',
    "drawtext=fontfile='$fontPath'"
        ":textfile='$textFilePath'"
        ':x=$x:y=$y:fontsize=$fontSize'
        ':fontcolor=white:borderw=3:bordercolor=black',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23',
    '-preset', 'fast',
    '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
    outputPath,
  ];
}

/// Argv for the concat-demuxer montage pass — the exact argument order of
/// the legacy interpolated command, minus its quoting.
List<String> buildConcatArgs({
  required String concatListPath,
  required String outputPath,
}) {
  return [
    '-y', '-f', 'concat', '-safe', '0', '-i', concatListPath,
    '-c:v', 'libx264', '-crf', '23', '-preset', 'fast',
    '-c:a', 'aac', '-b:a', '128k',
    outputPath,
  ];
}
