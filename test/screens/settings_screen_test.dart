import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/screens/settings_screen.dart';

void main() {
  setUp(() {
  });

  Future<StorageService> makeStorage({String visualStyle = 'retro'}) async {
    SharedPreferences.setMockInitialValues({
      'crt_effects': false,
      'visual_style': visualStyle,
    });
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  Widget buildSettings(StorageService storage) {
    AppTheme.visualStyle = storage.getVisualStyle();
    return MaterialApp(
      theme: AppTheme.buildTheme(Brightness.dark, const Color(0xFF00FF00)),
      home: SettingsScreen(
        storageService: storage,
        onThemeChanged: (_, __) {},
      ),
    );
  }

  group('Visual Style picker', () {
    testWidgets('shows RETRO, MODERN, and HEARTH segments', (tester) async {
      final storage = await makeStorage();
      await tester.pumpWidget(buildSettings(storage));
      await tester.pumpAndSettle();

      expect(find.text('RETRO'),  findsOneWidget);
      expect(find.text('MODERN'), findsOneWidget);
      expect(find.text('HEARTH'), findsOneWidget);
    });

    testWidgets('selecting HEARTH persists to prefs', (tester) async {
      final storage = await makeStorage(visualStyle: 'retro');
      await tester.pumpWidget(buildSettings(storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('HEARTH'));
      await tester.pumpAndSettle();

      expect(storage.getVisualStyle(), 'hearth');
      expect(AppTheme.visualStyle, 'hearth');
    });

    testWidgets('selecting MODERN persists to prefs', (tester) async {
      final storage = await makeStorage(visualStyle: 'retro');
      await tester.pumpWidget(buildSettings(storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('MODERN'));
      await tester.pumpAndSettle();

      expect(storage.getVisualStyle(), 'modern');
      expect(AppTheme.visualStyle, 'modern');
    });
  });

  group('Accent color picker', () {
    testWidgets('accent color swatches visible in retro mode', (tester) async {
      final storage = await makeStorage(visualStyle: 'retro');
      await tester.pumpWidget(buildSettings(storage));
      await tester.pumpAndSettle();

      expect(find.text('Accent Color'), findsOneWidget);
      expect(find.text('Fixed Hearth terracotta'), findsNothing);
    });

    testWidgets('accent color swatches visible in modern mode', (tester) async {
      final storage = await makeStorage(visualStyle: 'modern');
      await tester.pumpWidget(buildSettings(storage));
      await tester.pumpAndSettle();

      expect(find.text('Accent Color'), findsOneWidget);
      expect(find.text('Fixed Hearth terracotta'), findsNothing);
    });

    testWidgets('fixed swatch shown in hearth mode', (tester) async {
      final storage = await makeStorage(visualStyle: 'hearth');
      await tester.pumpWidget(buildSettings(storage));
      await tester.pumpAndSettle();

      expect(find.text('Accent Color'), findsOneWidget);
      expect(find.text('Fixed Hearth terracotta'), findsOneWidget);
    });
  });

  group('CRT Scanlines toggle', () {
    testWidgets('visible in retro mode', (tester) async {
      final storage = await makeStorage(visualStyle: 'retro');
      await tester.pumpWidget(buildSettings(storage));
      await tester.pumpAndSettle();

      expect(find.text('CRT Scanlines'), findsOneWidget);
    });

    testWidgets('hidden in modern mode', (tester) async {
      final storage = await makeStorage(visualStyle: 'modern');
      await tester.pumpWidget(buildSettings(storage));
      await tester.pumpAndSettle();

      expect(find.text('CRT Scanlines'), findsNothing);
    });

    testWidgets('hidden in hearth mode', (tester) async {
      final storage = await makeStorage(visualStyle: 'hearth');
      await tester.pumpWidget(buildSettings(storage));
      await tester.pumpAndSettle();

      expect(find.text('CRT Scanlines'), findsNothing);
    });
  });
}
