import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/widgets/crt_effects.dart';

void main() {
  group('RetroButton sizing', () {
    testWidgets('shrink-wraps its child in unconstrained parent',
        (WidgetTester tester) async {
      AppTheme.visualStyle = 'retro';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 500,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RetroButton(
                    onPressed: () {},
                    child: const Text('TAP'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(RetroButton);
      expect(buttonFinder, findsOneWidget);

      final buttonSize = tester.getSize(buttonFinder);
      // Button width should be much smaller than the 500px parent
      expect(buttonSize.width, lessThan(250));
    });

    testWidgets('fires onPressed callback when tapped',
        (WidgetTester tester) async {
      AppTheme.visualStyle = 'retro';
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
          home: Scaffold(
            body: Center(
              child: RetroButton(
                onPressed: () => tapped = true,
                child: const Text('TAP ME'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(RetroButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shrink-wraps in modern theme mode',
        (WidgetTester tester) async {
      AppTheme.visualStyle = 'modern';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(Brightness.dark, Colors.blue),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 500,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RetroButton(
                    onPressed: () {},
                    child: const Text('TAP'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final buttonSize = tester.getSize(find.byType(RetroButton));
      expect(buttonSize.width, lessThan(250));
      AppTheme.visualStyle = 'retro';
    });

    testWidgets('shrink-wraps in hearth theme mode',
        (WidgetTester tester) async {
      AppTheme.visualStyle = 'hearth';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(Brightness.dark, Colors.blue),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 500,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RetroButton(
                    onPressed: () {},
                    child: const Text('TAP'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final buttonSize = tester.getSize(find.byType(RetroButton));
      expect(buttonSize.width, lessThan(250));
      AppTheme.visualStyle = 'retro';
    });

    testWidgets('fires onPressed in hearth mode', (WidgetTester tester) async {
      AppTheme.visualStyle = 'hearth';
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(Brightness.dark, Colors.blue),
          home: Scaffold(
            body: Center(
              child: RetroButton(
                onPressed: () => tapped = true,
                child: const Text('TAP ME'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(RetroButton));
      await tester.pump();

      expect(tapped, isTrue);
      AppTheme.visualStyle = 'retro';
    });
  });
}
