import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/widgets/crt_effects.dart';

import 'visual_golden_helper.dart';

void main() {
  testWidgets('RetroButton responsive golden sweep', (tester) async {
    // RetroButton's render path keys off AppTheme.visualStyle and reads
    // theme.colorScheme.primary for its fill (see lib/widgets/crt_effects.dart).
    AppTheme.visualStyle = 'retro';
    addTearDown(() => AppTheme.visualStyle = 'hearth');

    // PROJECT FRICTION (worth noting for the skill): AppTheme.buildTheme()
    // eagerly constructs google_fonts text styles (e.g. RobotoMono-Bold for its
    // button themes). The google_fonts package schedules the async font load at
    // TextStyle-construction time, so merely calling buildTheme() queues a load
    // that — in the headless test env where the font is neither bundled nor
    // fetchable — fails the golden test. We therefore use a plain ThemeData with
    // the SDK Roboto (loaded by flutter_test_config.dart) rather than the app
    // theme; this still exercises RetroButton's retro rendering. The widget's
    // own text is given an explicit Roboto style for the same reason.
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(primary: Colors.green),
    );

    await goldenAtSizes(
      tester,
      name: 'retro_button',
      sizes: const <String, Size>{
        'phone': Size(360, 740),
        'narrow': Size(320, 740),
      },
      textScales: const <double>[1.0, 3.0],
      theme: theme,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: RetroButton(
              onPressed: () {},
              child: const Text(
                'TAP ME',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });
}
