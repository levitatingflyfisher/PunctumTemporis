import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/widgets/crt_effects.dart';

Widget _buildBar(String visualStyle, {double value = 0.5}) {
  AppTheme.visualStyle = visualStyle;
  return MaterialApp(
    theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          child: RetroProgressBar(value: value),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(() => AppTheme.visualStyle = 'retro');

  group('RetroProgressBar', () {
    testWidgets('retro mode uses pixelated block layout (no ClipRRect)',
        (tester) async {
      await tester.pumpWidget(_buildBar('retro'));
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('modern mode uses smooth bar (has ClipRRect)', (tester) async {
      await tester.pumpWidget(_buildBar('modern'));
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('hearth mode uses smooth bar (has ClipRRect)', (tester) async {
      await tester.pumpWidget(_buildBar('hearth'));
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('renders at 0% without error', (tester) async {
      await tester.pumpWidget(_buildBar('hearth', value: 0.0));
      expect(find.byType(RetroProgressBar), findsOneWidget);
    });

    testWidgets('renders at 100% without error', (tester) async {
      await tester.pumpWidget(_buildBar('hearth', value: 1.0));
      expect(find.byType(RetroProgressBar), findsOneWidget);
    });
  });
}
