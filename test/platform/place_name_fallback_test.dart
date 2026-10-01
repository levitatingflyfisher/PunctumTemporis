// Place names from assets/data/cities.csv carry Latin Extended and
// Vietnamese letters the bundled faces lack (Retro's VT323 and Press Start
// 2P, Hearth's Lora and Nunito). They draw through the engine's fallback
// fonts, which needs two things to stay true (batch-2 ruling; recorded in
// test/fleet_conformance_test.dart's assetTextLatinFallback):
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

void main() {
  test('nothing in lib/ pins a font fallback list that would stop the '
      'engine reaching system fonts', () {
    final hits = [
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
        if (f.readAsStringSync().contains('fontFamilyFallback')) f.path,
    ];
    expect(hits, isEmpty);
  });

  test('the web build fetches missing glyphs from the shared Noto mirror', () {
    final boot = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(boot, contains(kFleetFontFallbackBaseUrl));
  });
}
