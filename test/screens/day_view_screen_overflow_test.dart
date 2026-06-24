import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/screens/day_view_screen.dart';

/// Accessibility-overflow regression test for [DayViewScreen]'s empty-day state.
///
/// The empty-day "CAPTURE" button is a horizontal Row (icon + label). At a
/// narrow width (320dp) with a large accessibility text scale (×3.0) that Row
/// overflowed with a `RenderFlex overflowed` error. Pumping the empty-day page
/// at that worst-case combination and asserting no exception guards the fix.
void main() {
  late StorageService storageService;

  setUp(() async {
    AppTheme.visualStyle = 'retro';
    addTearDown(() => AppTheme.visualStyle = 'hearth');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'crt_effects': false,
    });
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  testWidgets('DayViewScreen empty-day does not overflow at 320dp / scale 3.0',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 800);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(3.0)),
        child: child!,
      ),
      home: DayViewScreen(
        storageService: storageService,
        initialDate: DateTime(2026, 5, 14), // past date → capturable empty day
        onDelete: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
