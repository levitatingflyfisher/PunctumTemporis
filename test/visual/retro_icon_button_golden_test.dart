import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/widgets/crt_effects.dart';

import 'visual_golden_helper.dart';

void main() {
  testWidgets('RetroIconButton responsive golden sweep', (tester) async {
    // RetroIconButton keys off AppTheme.visualStyle (offset hard-shadow square
    // in retro, soft rounded button otherwise) and reads
    // theme.colorScheme.primary/surface. Its glyph is a MaterialIcons icon
    // (no google_fonts text). Exercise the retro path; restore the default.
    AppTheme.visualStyle = 'retro';
    addTearDown(() => AppTheme.visualStyle = 'hearth');

    // Plain ThemeData backed by SDK Roboto/MaterialIcons (loaded by
    // flutter_test_config.dart) — bypasses AppTheme.buildTheme()'s google_fonts
    // load that fails headless. See references/flutter.md.
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(primary: Colors.green),
    );

    await goldenAtSizes(
      tester,
      name: 'retro_icon_button',
      sizes: const <String, Size>{
        'phone': Size(360, 740),
        'narrow': Size(320, 740),
      },
      textScales: const <double>[1.0, 3.0],
      theme: theme,
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: RetroIconButton(
              onPressed: null,
              icon: Icons.play_arrow,
            ),
          ),
        ),
      ),
    );
  });
}
