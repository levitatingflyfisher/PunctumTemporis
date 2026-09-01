// C12 (accent vs error) found one preset too close to the urgency red:
// Coral 0xFFFF6B6B sat CIEDE2000 10.2 from the dark theme's error colour
// 0xFFFF939C (floor 12), so in Retro/Modern dark every Coral button read as
// a warning. Coral moves to 0xFFFF8C69 (14.2 from it, and 12.3 from
// Tangerine, so the two presets stay apart). The accent is stored as an
// int, so a household that picked the old Coral is carried to the new one
// on read, and keeps its choice selected in Settings.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Coral is the new, distinct value', () {
    expect(AppTheme.accentPresets['Coral'], const Color(0xFFFF8C69));
    expect(AppTheme.accentPresets.values,
        isNot(contains(const Color(0xFFFF6B6B))));
  });

  test('a stored old Coral reads back as the new Coral', () async {
    SharedPreferences.setMockInitialValues({'accent_color': 0xFFFF6B6B});
    final svc = StorageService(await SharedPreferences.getInstance());
    expect(svc.getAccentColor(), 0xFFFF8C69);
  });

  test('every other stored accent reads back unchanged', () async {
    SharedPreferences.setMockInitialValues({'accent_color': 0xFF00BFFF});
    final svc = StorageService(await SharedPreferences.getInstance());
    expect(svc.getAccentColor(), 0xFF00BFFF);
  });
}
