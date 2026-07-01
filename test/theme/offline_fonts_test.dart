import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';

/// Punctum Temporis is local-first: every visual style's fonts are BUNDLED
/// (assets/fonts/, declared in pubspec) and referenced by family — never fetched
/// from fonts.gstatic.com at runtime. google_fonts fetched Lora/Nunito/VT323/
/// Press Start 2P/Roboto Mono on first use; these assertions lock the bundled
/// family names so a regression back to runtime font egress fails the build.
void main() {
  tearDown(() => AppTheme.visualStyle = 'hearth');

  test('hearth (default) uses bundled Lora/Nunito', () {
    AppTheme.visualStyle = 'hearth';
    expect(AppTheme.displayFont().fontFamily, 'Lora');
    expect(AppTheme.headingFont().fontFamily, 'Lora');
    expect(AppTheme.pixelFont().fontFamily, 'Nunito');
    expect(AppTheme.monoFont().fontFamily, 'Nunito');
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
