// FFmpeg arg-injection guard (fleet finding, ffmpeg_runner_native.dart:228/:163).
//
// The native runner used to hand FFmpegKit.execute() ONE interpolated string
// with double-quoted paths — a '"' in a clip path (or a quote in the concat
// list) closed the quoted token and the remainder became injected ffmpeg argv.
// The fix is structural: pure List<String> builders (tested here) fed to
// FFmpegKit.executeWithArguments(), where each path is one discrete argv
// element and no shell-style tokenization ever happens. The drawtext overlay
// TEXT still goes through ffmpeg's own text expansion, so its special chars
// (\ : ' %) are escaped per the drawtext rules.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/platform/ffmpeg_args.dart';

void main() {
  group('escapeDrawtextText', () {
    test('leaves plain overlay text unchanged', () {
      expect(escapeDrawtextText('JUL 4 2026 : PARIS'), r'JUL 4 2026 \: PARIS');
      expect(escapeDrawtextText('JUL 4 2026'), 'JUL 4 2026');
    });

    test('escapes the drawtext-special characters \\ : \' %', () {
      expect(escapeDrawtextText(r'a\b'), r'a\\b');
      expect(escapeDrawtextText('10:30'), r'10\:30');
      expect(escapeDrawtextText("O'NEILL"), r"O\'NEILL");
      expect(escapeDrawtextText('100%'), r'100\%');
    });

    test('neutralizes a %{...} expansion sequence', () {
      // Un-escaped, drawtext would EXPAND this instead of drawing it.
      expect(escapeDrawtextText('%{pts}'), r'\%{pts}');
    });

    test('escapes the backslash before other escapes (no double-escaping)', () {
      expect(escapeDrawtextText(r'\:'), r'\\\:');
    });
  });

  group('concatListEntry', () {
    test('wraps a plain path in single quotes', () {
      expect(concatListEntry('/a/b.mp4'), "file '/a/b.mp4'");
    });

    test("a single quote in the path cannot terminate the quoted token", () {
      // ffconcat quoting: close the quote, emit \', reopen — the classic
      // '\'' idiom. Without it, the quote ends the token and the rest of
      // the path is parsed as further concat directives.
      expect(concatListEntry("/a/it's.mp4"), r"file '/a/it'\''s.mp4'");
    });
  });

  group('buildDateOverlayArgs', () {
    test('keeps the exact legacy argument order, paths as whole argv', () {
      final args = buildDateOverlayArgs(
        inputPath: '/in/my "clip".mp4',
        outputPath: '/out/o.mp4',
        fontPath: '/system/fonts/Roboto-Regular.ttf',
        textFilePath: '/tmp/overlay_text_1.txt',
        x: '30',
        y: 'h-th-30',
        fontSize: 36,
      );
      expect(args, [
        '-y',
        '-i',
        '/in/my "clip".mp4',
        '-vf',
        "drawtext=fontfile='/system/fonts/Roboto-Regular.ttf'"
            ":textfile='/tmp/overlay_text_1.txt'"
            ':x=30:y=h-th-30:fontsize=36'
            ':fontcolor=white:borderw=3:bordercolor=black',
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30', '-crf', '23',
        '-preset', 'fast',
        '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-b:a', '128k',
        '/out/o.mp4',
      ]);
    });

    test('a quote-bearing input path stays exactly one argv element', () {
      final args = buildDateOverlayArgs(
        inputPath: 'a".mp4',
        outputPath: 'o.mp4',
        fontPath: 'f.ttf',
        textFilePath: 't.txt',
        x: '30',
        y: '30',
        fontSize: 36,
      );
      expect(args.where((a) => a == 'a".mp4').length, 1,
          reason: 'the path must never be wrapped into a quoted blob '
              'that a \'"\' could break out of');
    });
  });

  group('buildConcatArgs', () {
    test('keeps the exact legacy argument order, paths as whole argv', () {
      final args = buildConcatArgs(
        concatListPath: '/tmp/concat_list.txt',
        outputPath: '/out/monta ge".mp4',
      );
      expect(args, [
        '-y', '-f', 'concat', '-safe', '0', '-i', '/tmp/concat_list.txt',
        '-c:v', 'libx264', '-crf', '23', '-preset', 'fast',
        '-c:a', 'aac', '-b:a', '128k',
        '/out/monta ge".mp4',
      ]);
    });
  });
}
