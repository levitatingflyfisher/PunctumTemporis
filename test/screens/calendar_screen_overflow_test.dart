import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/screens/calendar_screen.dart';

/// Accessibility-overflow regression test for [CalendarScreen].
///
/// The header, month navigator, stats footer, and floating CAPTURE button are
/// all horizontal Rows of fixed-size children. At a narrow width (320dp) with a
/// large accessibility text scale (×3.0) those Rows overflowed with
/// `RenderFlex overflowed` errors. Pumping the screen at that worst-case
/// combination and asserting no exception is thrown guards against regressions.
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

  testWidgets('CalendarScreen does not overflow at 320dp / textScale 3.0',
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
      home: CalendarScreen(
        storageService: storageService,
        onThemeChanged: (_, __) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
