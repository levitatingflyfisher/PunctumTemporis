import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// House style for words on screen: no spaced em dashes, and typographic
/// apostrophes and quotes (’ “ ”) rather than typewriter ones (' ").
/// A source scan over string literals in lib/: comments, imports and log
/// lines are ignored. (The scan Sundial, Furrow and Peckish run; the fleet
/// has no shared home for it yet.) Exempt, because their quotes are syntax,
/// not copy: the FFmpeg argument and filter builders.
const _exempt = [
  'ffmpeg_args.dart',
  'ffmpeg_runner_native.dart',
  'ffmpeg_runner_web.dart',
  // Its '"' is a character the name sanitizer strips, not copy.
  'person_name.dart',
];

void main() {
  final literal = RegExp(r'"([^"\\]|\\.)*"' "|" r"'([^'\\]|\\.)*'");

  Iterable<(String, int, String)> literals() sync* {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .where((f) => !_exempt.any(f.path.endsWith));
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final t = line.trimLeft();
        if (t.startsWith('//') || line.contains('debugPrint(')) continue;
        if (t.startsWith('import ') || t.startsWith('export ')) continue;
        if (t.startsWith('part ')) continue;
        // Assertion messages are for developers, not the screen.
        if (t.startsWith('assert(') || t.startsWith("'Unknown ")) continue;
        for (final m in literal.allMatches(line)) {
          // Code inside an interpolation is not copy: `${x ?? "1.0"}`.
          var lit = m.group(0)!;
          for (var prev = ''; prev != lit;) {
            prev = lit;
            lit = lit.replaceAll(RegExp(r'\$\{[^{}]*\}'), r'$x');
          }
          yield (f.path, i + 1, lit);
        }
      }
    }
  }

  test('no spaced em dash in on-screen copy', () {
    final hits = [
      for (final (path, line, lit) in literals())
        // A dash before an escaped newline is still a spaced dash.
        if (lit.contains(' — ') || RegExp(r' —(\\n)*' "['\"]\$").hasMatch(lit))
          '$path:$line $lit',
    ];
    expect(hits, isEmpty);
  });

  test('no typewriter apostrophe or quote inside on-screen copy', () {
    final apostrophe = RegExp(r"[A-Za-z]'[A-Za-z]");
    final escaped = RegExp(r"[A-Za-z}]\\'[A-Za-z]");
    final hits = [
      for (final (path, line, lit) in literals())
        if ((lit.startsWith('"') &&
                apostrophe.hasMatch(lit.substring(1, lit.length - 1))) ||
            (lit.startsWith("'") &&
                (lit.substring(1, lit.length - 1).contains('"') ||
                    escaped.hasMatch(lit))))
          '$path:$line $lit',
    ];
    expect(hits, isEmpty);
  });
}
