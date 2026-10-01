// web/coi-serviceworker.js never ran: its top-level `return` is a
// SyntaxError in a classic script, logged on every load (nocdn3). It was
// there to make the page cross-origin isolated for a multi-threaded
// ffmpeg, but the bundled core is the single-threaded build, which needs no
// SharedArrayBuffer, and export works without it. Ruling: remove it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no cross-origin-isolation worker is shipped or loaded', () {
    expect(File('web/coi-serviceworker.js').existsSync(), isFalse);
    expect(File('web/index.html').readAsStringSync(),
        isNot(contains('coi-serviceworker')));
  });

  test('the bundled ffmpeg core is the single-threaded one', () {
    final names = Directory('web/ffmpeg')
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .toSet();
    expect(names, contains('ffmpeg-core.wasm'));
    // The multi-threaded core ships a pthread worker; this one does not,
    // so nothing needs SharedArrayBuffer.
    expect(names, isNot(contains('ffmpeg-core.worker.js')));
  });
}
