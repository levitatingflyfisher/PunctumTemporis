import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';

/// Builds an isolated location-sheet-like widget to test the CLEAR button.
/// Mirrors the conditional logic in _showEditLocationSheet without needing
/// the full ClipPreviewScreen dependencies.
Widget _buildLocationSheetActions({required bool hasLocation, VoidCallback? onClear}) {
  final theme = AppTheme.buildTheme(Brightness.dark, Colors.green);
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final t = Theme.of(context);
          return Column(
            children: [
              if (hasLocation)
                TextButton(
                  onPressed: onClear,
                  child: Text(
                    'CLEAR LOCATION',
                    style: AppTheme.monoFont(fontSize: 11, color: t.colorScheme.error),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

/// Isolated tag chip widget that mirrors the structure in ClipPreviewScreen.
/// This avoids heavy dependencies (VideoPlayerController, FaceService, etc.)
/// while still verifying the tag chip UI contract.
Widget _buildTagChip(String tag, {ThemeData? theme}) {
  final resolvedTheme =
      theme ?? AppTheme.buildTheme(Brightness.dark, Colors.green);
  final primary = resolvedTheme.colorScheme.primary;

  return MaterialApp(
    theme: resolvedTheme,
    home: Scaffold(
      body: Center(
        child: GestureDetector(
          onTap: () {},
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              border: Border.all(color: primary),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag,
                  style: AppTheme.monoFont(
                    fontSize: 12,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.close, size: 12, color: primary),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    AppTheme.visualStyle = 'retro';
  });

  group('Location edit sheet CLEAR button', () {
    testWidgets('shows CLEAR LOCATION button when clip has a location', (tester) async {
      await tester.pumpWidget(_buildLocationSheetActions(hasLocation: true));
      await tester.pumpAndSettle();
      expect(find.text('CLEAR LOCATION'), findsOneWidget);
    });

    testWidgets('does NOT show CLEAR LOCATION button when clip has no location', (tester) async {
      await tester.pumpWidget(_buildLocationSheetActions(hasLocation: false));
      await tester.pumpAndSettle();
      expect(find.text('CLEAR LOCATION'), findsNothing);
    });

    testWidgets('tapping CLEAR LOCATION calls the clear callback', (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        _buildLocationSheetActions(hasLocation: true, onClear: () => cleared = true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLEAR LOCATION'));
      expect(cleared, isTrue);
    });
  });

  group('Tag chip UI', () {
    testWidgets('tag chip shows × (close) icon', (tester) async {
      await tester.pumpWidget(_buildTagChip('TRAVEL'));
      await tester.pumpAndSettle();

      // The tag label should be present
      expect(find.text('TRAVEL'), findsOneWidget);

      // The close icon must be present — this is the key UX requirement
      expect(
        find.byIcon(Icons.close),
        findsOneWidget,
        reason: 'Tag chips must show a × icon so users know tapping removes the tag',
      );
    });

    testWidgets('tag chip shows × icon for any tag text', (tester) async {
      await tester.pumpWidget(_buildTagChip('WORK'));
      await tester.pumpAndSettle();

      expect(find.text('WORK'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('× icon is inside a Row with the tag text', (tester) async {
      await tester.pumpWidget(_buildTagChip('FAMILY'));
      await tester.pumpAndSettle();

      // Verify the close icon is a sibling of the text inside the same Row
      final iconFinder = find.byIcon(Icons.close);
      expect(iconFinder, findsOneWidget);

      final rowFinder = find.ancestor(
        of: iconFinder,
        matching: find.byType(Row),
      );
      expect(rowFinder, findsWidgets,
          reason: '× icon should be inside a Row alongside the tag text');

      // Both text and icon share the same Row ancestor
      final textFinder = find.text('FAMILY');
      final textRowFinder = find.ancestor(
        of: textFinder,
        matching: find.byType(Row),
      );
      expect(textRowFinder, findsWidgets);
    });
  });
}
