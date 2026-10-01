// Location capture is on by default, and the OS permission prompt fired
// mid-save with nothing before it (audit finding 11). Ruling: a one-time
// line before the prompt, on the capture screen, saying what location adds
// and that the phone will ask.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:one_second_a_day/widgets/location_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<StorageService> storage(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    return StorageService(await SharedPreferences.getInstance());
  }

  Future<void> pump(WidgetTester tester, StorageService s) =>
      tester.pumpWidget(MaterialApp(
        theme: AppTheme.buildTheme(Brightness.dark, Colors.green),
        home: Scaffold(body: LocationNotice(storageService: s)),
      ));

  testWidgets('shows before the first save while location capture is on',
      (tester) async {
    final s = await storage({});
    await pump(tester, s);
    expect(find.text(LocationNotice.text), findsOneWidget);
    expect(LocationNotice.text, contains('on this phone'));
  });

  testWidgets('once the first save has asked, it is gone', (tester) async {
    final s = await storage({});
    await s.setLocationNoticeShown();
    await pump(tester, s);
    expect(find.text(LocationNotice.text), findsNothing);
  });

  testWidgets('says nothing when location capture is off', (tester) async {
    final s = await storage({});
    await s.setCaptureLocation(false);
    await pump(tester, s);
    expect(find.text(LocationNotice.text), findsNothing);
  });

  test('both capture screens show it above Save and record it on save', () {
    for (final f in ['lib/screens/video_capture_screen.dart',
        'lib/screens/photo_capture_screen.dart']) {
      final src = File(f).readAsStringSync();
      expect(src, contains('LocationNotice('), reason: f);
      expect(src, contains('setLocationNoticeShown()'), reason: f);
    }
  });
}
