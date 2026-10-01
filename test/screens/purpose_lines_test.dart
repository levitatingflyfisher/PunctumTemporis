// Purpose and privacy were never said in words (lens audit finding 11):
// SCAN FACES writes names to a clip with no stated purpose, and location
// capture was on by default with nothing saying what it does or where it
// stays. One line at each decision point, in the user's words.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/screens/clip_preview_screen.dart';
import 'package:one_second_a_day/screens/settings_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;

  setUp(() async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({'crt_effects': false});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  testWidgets('the face scan says what it does and where it stays',
      (tester) async {
    final clip = Clip(
      id: 'c',
      date: '2026-09-04',
      filePath: 'nonexistent/c.mp4',
      type: ClipType.video,
      createdAt: DateTime(2026, 9, 4),
    );
    storage.setClipsForTest({'2026-09-04': [clip]});
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: ClipPreviewScreen(storageService: storage, clip: clip),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text(ClipPreviewScreen.faceScanPurpose), findsOneWidget);
    expect(ClipPreviewScreen.faceScanPurpose, contains('on this phone'));
  });

  testWidgets('location capture says what it adds and that it stays here',
      (tester) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: SettingsScreen(storageService: storage, onThemeChanged: (_, __) {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text(SettingsScreen.locationPurpose), findsOneWidget);
    expect(SettingsScreen.locationPurpose, contains('on this phone'));
  });
}
