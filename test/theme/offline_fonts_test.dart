import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';

/// Punctum Temporis is local-first: every visual style's fonts are BUNDLED
/// (assets/fonts/, declared in pubspec) and referenced by family — never fetched
/// from fonts.gstatic.com at runtime. google_fonts fetched Lora/Nunito/VT323/
/// Press Start 2P/Roboto Mono on first use; these assertions lock the bundled
/// family names so a regression back to runtime font egress fails the build.
///
/// Since openhearth_design 0.7.1 Hearth's Lora/Nunito are that package's
/// fonts, not copies this app ships: the family is the package-qualified
/// 'packages/openhearth_design/Lora' — still a local asset. The Retro and
/// Modern faces (VT323, Press Start 2P, Roboto Mono) stay PT's own.
const _lora = 'packages/openhearth_design/Lora';
const _nunito = 'packages/openhearth_design/Nunito';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => AppTheme.visualStyle = 'hearth');

  test('hearth (default) uses the package Lora/Nunito', () {
    AppTheme.visualStyle = 'hearth';
    expect(AppTheme.displayFont().fontFamily, _lora);
    expect(AppTheme.headingFont().fontFamily, _lora);
    expect(AppTheme.pixelFont().fontFamily, _nunito);
    expect(AppTheme.monoFont().fontFamily, _nunito);
  });

  test('every family the styles name is declared and its files resolve',
      () async {
    final manifest =
        json.decode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final families = manifest
        .cast<Map<String, dynamic>>()
        .map((e) => e['family'] as String)
        .toSet();
    expect(families,
        containsAll([_lora, _nunito, 'VT323', 'Press Start 2P', 'Roboto Mono']));
    for (final asset in [
      'packages/openhearth_design/fonts/Lora-Regular.ttf',
      'packages/openhearth_design/fonts/Nunito-Regular.ttf',
      'assets/fonts/VT323-Regular.ttf',
    ]) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  test('retro uses bundled VT323 / Press Start 2P / Roboto Mono', () {
    AppTheme.visualStyle = 'retro';
    expect(AppTheme.displayFont().fontFamily, 'VT323');
    expect(AppTheme.pixelFont().fontFamily, 'Press Start 2P');
    expect(AppTheme.monoFont().fontFamily, 'Roboto Mono');
  });

  test('modern uses bundled Roboto Mono', () {
    AppTheme.visualStyle = 'modern';
    expect(AppTheme.pixelFont().fontFamily, 'Roboto Mono');
    expect(AppTheme.monoFont().fontFamily, 'Roboto Mono');
  });
}
