// Back during a montage render (lens audit finding 12, mind-in-mind-02,
// persona E3). Before: PopScope swallowed the gesture and a SnackBar said
// to wait, with no way out for minutes. The contested choice was
// background rendering or cancel-with-confirmation; the audit named the
// second as the floor. Back now asks, with keep going first, and stopping
// cancels FFmpeg and leaves the clips untouched.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/compilation_screen.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<bool>(
            context: context,
            builder: CompilationScreen.buildStopDialog,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the question says what stops and what is safe', (tester) async {
    await open(tester);
    expect(find.text('Stop making this montage?'), findsOneWidget);
    expect(find.textContaining('Your clips aren’t touched'), findsOneWidget);
  });

  testWidgets('Keep going is the safe default and returns false',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog<bool>(
            context: context,
            builder: CompilationScreen.buildStopDialog,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final keep = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(keep.autofocus, isTrue);
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('Stop and discard returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog<bool>(
            context: context,
            builder: CompilationScreen.buildStopDialog,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop and discard'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
