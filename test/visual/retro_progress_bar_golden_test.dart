import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/widgets/crt_effects.dart';

import 'visual_golden_helper.dart';

void main() {
  testWidgets('RetroProgressBar responsive golden sweep', (tester) async {
    // RetroProgressBar's render path keys off AppTheme.visualStyle (pixelated
    // block row in retro, smooth ClipRRect bar otherwise) and reads
    // theme.colorScheme.primary/surface for its colors. Exercise the retro
    // path; restore the project default afterwards.
    AppTheme.visualStyle = 'retro';
    addTearDown(() => AppTheme.visualStyle = 'hearth');

    // Bypass AppTheme.buildTheme() — it eagerly constructs google_fonts text
    // styles whose async load fails in the headless golden env. A plain
    // ThemeData backed by the SDK Roboto (loaded by flutter_test_config.dart)
    // exercises the same layout/render path. See references/flutter.md.
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(primary: Colors.green),
    );

    await goldenAtSizes(
      tester,
      name: 'retro_progress_bar',
      sizes: const <String, Size>{
        'phone': Size(360, 740),
        'narrow': Size(320, 740),
      },
      textScales: const <double>[1.0, 3.0],
      theme: theme,
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RetroProgressBar(value: 0.5),
              ],
            ),
          ),
        ),
      ),
    );
  });
}
