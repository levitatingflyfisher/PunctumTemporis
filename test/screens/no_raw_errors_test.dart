// Never render an exception to the person holding the phone; log it (fleet
// rule, lens audit finding 1 / humane-interface-03).
//
// Conformance C10 cannot see PT's raw errors: every one went through a
// screen's `_showError(String)` helper, which builds the SnackBar's Text
// from a parameter, so the `$e` sits in the helper's CALL, not in a Text.
// This scan reads the calls themselves: the argument of every
// `_showError(`, `SnackBar(` and `Text(` in lib/ must not interpolate a
// caught error or call its toString().
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _rawError = RegExp(
    r'\$(e|err|error|ex)\b|\$\{(e|err|error|ex)\b|\b(e|err|error|ex)\.toString\(\)');

/// The argument text of each call to [callee] in [src], by paren matching.
Iterable<(int, String)> _calls(String src, String callee) sync* {
  var from = 0;
  while (true) {
    final start = src.indexOf('$callee(', from);
    if (start < 0) return;
    // Skip identifiers that merely end in the callee name.
    if (start > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(src[start - 1])) {
      from = start + 1;
      continue;
    }
    var depth = 0;
    var i = start + callee.length;
    for (; i < src.length; i++) {
      final ch = src[i];
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    final line = '\n'.allMatches(src.substring(0, start)).length + 1;
    yield (line, src.substring(start, i < src.length ? i + 1 : src.length));
    from = start + 1;
  }
}

void main() {
  test('no screen shows a caught exception in a SnackBar or Text', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final callee in ['_showError', 'SnackBar', 'Text']) {
        for (final (line, call) in _calls(src, callee)) {
          if (_rawError.hasMatch(call)) {
            offenders.add('${f.path}:$line  ${call.split('\n').first}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Show ohFriendlyErrorMessage(e) or a sentence of your own, '
            'and log the exception:\n${offenders.join('\n')}');
  });

  test('the scan bites: it finds a seeded offender', () {
    const seeded = '''
      } catch (e) {
        _showError('Camera error: \$e');
      }
    ''';
    final hits = _calls(seeded, '_showError')
        .where((c) => _rawError.hasMatch(c.$2))
        .toList();
    expect(hits, hasLength(1));
  });
}
