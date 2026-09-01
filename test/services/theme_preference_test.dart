// Theme: light, dark, or follow the phone, default follow the phone (fleet
// theme ruling, 2026-09-26).
//
// PT already stored a three-way int under 'theme_mode' (0 dark, 1 light,
// 2 system) with DARK as the default when nothing was stored. The key and its
// encoding stay (backups and snapshots carry 'theme_mode' as an int, so a
// new key would split old and new archives); only the unset default moves:
//   * nothing stored -> follow phone (the new best default),
//   * a stored 0 stays dark: it is only ever written by a person using
//     Settings, so it is what they are looking at today,
//   * 1 -> light, 2 -> follow phone, anything else -> follow phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/main.dart';
import 'package:one_second_a_day/services/backup_service.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StorageService> _svc(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  return StorageService(await SharedPreferences.getInstance());
}

void main() {
  test('a fresh install follows the phone', () async {
    final svc = await _svc({});
    expect(svc.getThemePreference(), OhThemeModePreference.system);
  });

  test('a stored dark stays dark', () async {
    final svc = await _svc({'theme_mode': 0});
    expect(svc.getThemePreference(), OhThemeModePreference.dark);
  });

  test('a stored light stays light', () async {
    final svc = await _svc({'theme_mode': 1});
    expect(svc.getThemePreference(), OhThemeModePreference.light);
  });

  test('a stored system follows the phone', () async {
    final svc = await _svc({'theme_mode': 2});
    expect(svc.getThemePreference(), OhThemeModePreference.system);
  });

  test('an unknown stored value follows the phone', () async {
    final svc = await _svc({'theme_mode': 7});
    expect(svc.getThemePreference(), OhThemeModePreference.system);
  });

  test('a choice is written in the int encoding backups carry', () async {
    final svc = await _svc({});
    await svc.setThemePreference(OhThemeModePreference.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('theme_mode'), 0);
    await svc.setThemePreference(OhThemeModePreference.light);
    expect(prefs.getInt('theme_mode'), 1);
    await svc.setThemePreference(OhThemeModePreference.system);
    expect(prefs.getInt('theme_mode'), 2);
    expect(svc.getThemePreference(), OhThemeModePreference.system);
  });

  for (final (stored, mode) in [
    (null, ThemeMode.system),
    (0, ThemeMode.dark),
    (1, ThemeMode.light),
    (2, ThemeMode.system),
  ]) {
    testWidgets('the app hands MaterialApp themeMode $mode for $stored',
        (tester) async {
      final svc = await _svc({
        if (stored != null) 'theme_mode': stored,
        'onboarding_complete': true,
        'crt_effects': false,
      });
      await tester.pumpWidget(OneSecondApp(
        storageService: svc,
        backupServiceFactory: () => BackupService(svc,
            vault: BackupVault(InMemoryVaultStore(),
                appId: 'punctum', extension: 'json')),
      ));
      await tester.pump();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, mode);
      expect(app.theme!.brightness, Brightness.light);
      expect(app.darkTheme!.brightness, Brightness.dark);
    });
  }
}
