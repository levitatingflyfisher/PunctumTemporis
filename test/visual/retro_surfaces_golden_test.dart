import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/widgets/crt_effects.dart';

import 'visual_golden_helper.dart';

/// Goldens for the self-contained retro surface widgets — RetroCard, GlowBorder,
/// and a static RetroIconButton. These take an explicit child / read only
/// theme.colorScheme (no internal google_fonts calls and no infinite
/// animations — RecordingIndicator/BlinkingIndicator are excluded because their
/// repeating controllers hang pumpAndSettle), so they render cleanly in
/// headless goldens. We give the sample Text an explicit Roboto style so the
/// label is readable rather than a fallback box.
///
/// Swept across phone/narrow × textScale 1.0/3.0 to surface any accessibility
/// overflow in the bordered/padded layouts.
void main() {
  testWidgets('Retro surfaces responsive golden sweep', (tester) async {
    AppTheme.visualStyle = 'retro';
    addTearDown(() => AppTheme.visualStyle = 'hearth');

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(primary: Colors.green),
    );

    const labelStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    await goldenAtSizes(
      tester,
      name: 'retro_surfaces',
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                RetroCard(
                  child: Text('RETRO CARD', style: labelStyle),
                ),
                SizedBox(height: 24),
                GlowBorder(
                  color: Colors.green,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('GLOW BORDER', style: labelStyle),
                  ),
                ),
                SizedBox(height: 24),
                Center(
                  child: RetroIconButton(
                    onPressed: null,
                    icon: Icons.fiber_manual_record,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  });
}
