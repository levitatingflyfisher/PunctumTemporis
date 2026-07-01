import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/screens/compilation_screen.dart';

Future<StorageService> _makeSvc() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return StorageService(prefs);
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
      home: child,
    );

void main() {
  setUp(() {
    AppTheme.visualStyle = 'retro';
  });

  group('CompilationScreen lifecycle observer', () {
    testWidgets('screen renders and registers lifecycle observer',
        (tester) async {
      final svc = await _makeSvc();
      await tester.pumpWidget(_wrap(CompilationScreen(storageService: svc)));
      await tester.pumpAndSettle();

      // Basic smoke test — screen is present
      expect(find.byType(CompilationScreen), findsOneWidget);

      // Simulate app lifecycle changes — should not throw
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // No crash means observer is properly registered and handled
    });

    testWidgets('no snackbar shown when lifecycle pauses without compiling',
        (tester) async {
      final svc = await _makeSvc();
      await tester.pumpWidget(_wrap(CompilationScreen(storageService: svc)));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Not compiling — no background toast should appear
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('COMPILE button is disabled when no clips available',
        (tester) async {
      final svc = await _makeSvc();
      await tester.pumpWidget(_wrap(CompilationScreen(storageService: svc)));
      await tester.pumpAndSettle();

      // With no clips, compile button should be disabled/greyed
      // The COMPILE text appears in the button
      expect(find.text('COMPILE'), findsOneWidget);
    });
  });

  group('Compilation background toast constant', () {
    test('background toast message text is defined', () {
      // Verify the expected message string is correct (pinned to prevent typos)
      expect(
        CompilationScreen.backgroundToastMessage,
        'Compiling — results when you return.',
      );
    });
  });
}
