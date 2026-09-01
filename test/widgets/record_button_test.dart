// The record button is a tap-to-start, tap-to-stop toggle: a mode. The
// ruling on the audit's hold-to-record contest is the floor both sides
// accepted: a mode is acceptable only while the control carries its own
// state (lens audit humane-interface-01 vs design-of-everyday-things, Q4).
// The shape already changes (circle -> rounded square); these tests pin
// that the button also says, in words a person and a screen reader can
// read, what a tap will do now.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/widgets/record_button.dart';

Widget _host(bool recording, VoidCallback onTap) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RecordButton(recording: recording, onTap: onTap),
        ),
      ),
    );

void main() {
  testWidgets('idle: the button says Record', (tester) async {
    await tester.pumpWidget(_host(false, () {}));
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
    expect(find.bySemanticsLabel('Start recording'), findsOneWidget);
  });

  testWidgets('recording: the button says Stop', (tester) async {
    await tester.pumpWidget(_host(true, () {}));
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Record'), findsNothing);
    expect(find.bySemanticsLabel('Stop recording'), findsOneWidget);
  });

  testWidgets('a tap anywhere on the control reaches onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(false, () => taps++));
    await tester.tap(find.text('Record'));
    await tester.tap(find.byType(RecordButton));
    expect(taps, 2);
  });
}
