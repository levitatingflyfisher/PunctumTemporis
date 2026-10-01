// Onboarding prose was centred with hard-coded line breaks (lens audit
// finding 8, the quick win both sides of the contested row accept):
// '\n' breaks land mid-line at any width or text size but the one they
// were typed for, and centred paragraphs are hard to read.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/onboarding_screen.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('onboarding paragraphs flow and start-align', (tester) async {
    AppTheme.visualStyle = 'hearth';
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(Brightness.light, Colors.green),
      home: OnboardingScreen(storageService: storage, onComplete: () {}),
    ));
    await tester.pumpAndSettle();

    for (var page = 0; page < 3; page++) {
      final paragraphs = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => (t.data ?? '').length > 40)
          .toList();
      expect(paragraphs, isNotEmpty, reason: 'page $page has a paragraph');
      for (final t in paragraphs) {
        expect(t.data, isNot(contains('\n')),
            reason: 'hard line break on page $page: ${t.data}');
        expect(t.textAlign, TextAlign.start,
            reason: 'centred paragraph on page $page');
      }
      if (page < 2) {
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }
    }
  });
}
