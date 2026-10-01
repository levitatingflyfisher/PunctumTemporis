// The web build's ffmpeg.wasm must load from the app's own origin, and
// nothing under web/ may name a third-party host the page could fetch.
//
// Two ways that broke before this test existed:
//  - The vendored worker (web/ffmpeg/814.ffmpeg.js) defaults coreURL to
//    unpkg.com. Any load() without a coreURL fetched code from a CDN.
//  - The runner passed 'ffmpeg/ffmpeg-core.js'. The worker resolves that
//    against its OWN URL (…/ffmpeg/814.ffmpeg.js), so it fetched
//    …/ffmpeg/ffmpeg/ffmpeg-core.js — a 404 — and video export on the web
//    never worked. The runner now resolves against the page's base URI.
//
// C13 only looks for Google hosts, so it saw neither.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/platform/ffmpeg_web_assets.dart';

final _url = RegExp(r'''https?://[^\s"'`)\\]+''');

/// URLs that appear under web/ but are never fetched, each with why.
const _neverFetched = {
  // In an emscripten error message about dynamic linking.
  'https://emscripten.org/docs/compiling/Dynamic-Linking.html',
  // Source credit in comments (index.html, coi-serviceworker.js).
  'https://github.com/gzuidhof/coi-serviceworker',
  // Flutter template comment about <base href> in index.html.
  'https://developer.mozilla.org/en-US/docs/Web/HTML/Element/base',
  // Placeholder links in web/version.json, which nothing in lib/ reads
  // (asserted below).
  'https://[C3_DOMAIN].org/downloads/one-second-a-day-v1.1.0.apk',
  'https://[C3_DOMAIN].org/apps/video-journal#changelog',
};

void main() {
  final vendored = Directory('web/ffmpeg')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.js'))
      .toList();

  test('the vendored ffmpeg JS is on disk', () {
    // Without this every assertion below passes over an empty list.
    expect(vendored.map((f) => f.uri.pathSegments.last),
        containsAll(['ffmpeg.js', '814.ffmpeg.js', 'ffmpeg-core.js']));
  });

  test('nothing under web/ names a third-party host it could fetch', () {
    final served = Directory('web')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => RegExp(r'\.(js|mjs|html|json|webmanifest)$')
            .hasMatch(f.path))
        .toList();
    expect(served.length, greaterThan(vendored.length));
    final offenders = <String>[];
    for (final f in served) {
      for (final m in _url.allMatches(f.readAsStringSync())) {
        if (!_neverFetched.contains(m[0])) {
          offenders.add('${f.path}: ${m[0]}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('nothing in lib/ reads web/version.json', () {
    // Its links are allowlisted above only because nothing fetches them.
    final readers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('version.json'))
        .map((f) => f.path)
        .toList();
    expect(readers, isEmpty);
  });

  test('every asset the runner loads exists under web/', () {
    for (final asset in ffmpegWebAssets) {
      expect(File('web/$asset').existsSync(), isTrue, reason: asset);
    }
  });

  group('ffmpegAssetUrl', () {
    test('resolves against the page base, not the worker', () {
      expect(
        ffmpegAssetUrl('https://h.example/PunctumTemporis/', ffmpegCoreJs),
        'https://h.example/PunctumTemporis/ffmpeg/ffmpeg-core.js',
      );
    });

    test('a deep route under the base does not change it', () {
      // baseURI is the <base href>, so this is what a deep link sees.
      expect(
        ffmpegAssetUrl('http://127.0.0.1:8080/PunctumTemporis/', ffmpegCoreWasm),
        'http://127.0.0.1:8080/PunctumTemporis/ffmpeg/ffmpeg-core.wasm',
      );
    });

    test('is always on the base origin', () {
      for (final asset in ffmpegWebAssets) {
        final u = Uri.parse(ffmpegAssetUrl('https://h.example/app/', asset));
        expect(u.origin, 'https://h.example');
      }
    });
  });

  test('the web runner passes resolved URLs for core and wasm', () {
    final src = File('lib/platform/ffmpeg_runner_web.dart').readAsStringSync();
    expect(src, contains('coreURL: ffmpegAssetUrl('));
    expect(src, contains('wasmURL: ffmpegAssetUrl('));
    expect(src, isNot(contains("coreURL: 'ffmpeg/")));
  });
}
