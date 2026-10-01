// PunctumTemporis' recorded fleet-standardization posture. Every deliberate
// divergence from fleet canon is a field HERE, not an unexplained delta:
//  * expectStartupMaintenance: false — PT drives the vault (freshness
//    snapshot + prune) from its own storage service in its own idiom
//    rather than the package's runStartupMaintenance hook.
//  * analysisOptionsOverrideRecorded — PT's analysis_options adds
//    avoid_print on top of the stock template (deliberately tighter).
import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';
import 'package:one_second_a_day/theme/app_theme.dart';

void main() => runFleetConformance(FleetAppConfig(
      appId: 'punctumtemporis',
      // Bundles its own type, so nothing falls back to a web font — a
      // character the bundled families cannot draw is a box on a
      // real phone. C7 sweeps lib/ for any.
      // C8: a bare IconButton.filled/.filledTonal would paint its glyph the
      // color of its own fill under ohStyle's ambient iconTheme. Filled
      // icon buttons must come from OhIconButton.
      checks: {
        // C13: the PWA loads nothing from Google's CDNs. web/flutter_bootstrap.js
        // points CanvasKit and the engine's fallback fonts at this origin.
        FleetCheck.c13WebSelfHosted,
        ...FleetAppConfig.withBundledFonts,
        FleetCheck.c8IconButtons,
        // C10: no caught exception rendered in a Text/TextSpan/errorText.
        // PT's screens report through _showError(String) helpers, which C10
        // cannot see into; test/screens/no_raw_errors_test.dart scans those
        // calls.
        FleetCheck.c10RawErrors,
        // C11: an icon-only AppBar action needs a name. The calendar's
        // header is not an AppBar (C11 cannot see it);
        // test/screens/calendar_header_test.dart holds its words.
        FleetCheck.c11IconLabels,
        // C12: no accent may look like the urgency red. PT's accent is a
        // runtime choice C12 cannot read from source, so every value the
        // app can render is recorded below.
        FleetCheck.c12AccentVsError,
        // C5-primaryScreens: the screens whose one job is a button must keep
        // it reachable at 360dp x 1.3 (test/a11y/primary_action_sweep_test).
        FleetCheck.c5PrimaryScreens,
        // C9 (routes) is deliberately off: PT has no GoRoute; every screen
        // is pushed with Navigator.push from a visible control.
      },
      accentColors: [
        // Hearth (the default style) ignores the stored accent and paints
        // hearth500 in both brightnesses.
        FleetAccent.light(AppTheme.hearthPrimary.toARGB32(), label: 'Hearth'),
        FleetAccent.dark(AppTheme.hearthPrimary.toARGB32(), label: 'Hearth'),
        // Retro and Modern render the chosen preset as primary, light or
        // dark (AppTheme.accentPresets).
        for (final preset in AppTheme.accentPresets.entries) ...[
          FleetAccent.light(preset.value.toARGB32(), label: preset.key),
          FleetAccent.dark(preset.value.toARGB32(), label: preset.key),
        ],
      ],
      primaryActionScreens: {
        'CalendarScreen',
        'CompilationScreen',
        'DayViewScreen',
      },
      styleTier: StyleTier.tokens,
      androidPermissions: {
        'android.permission.WRITE_EXTERNAL_STORAGE',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.READ_MEDIA_VIDEO',
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      },
      // C4 v2 — the release MERGED surface: source permissions plus
      // what plugins and the manifest merge inject. Bites when an APK
      // build has left a merged manifest under build/ (dev box).
      mergedAndroidPermissions: {
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_NETWORK_STATE',
        'android.permission.CAMERA',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.INTERNET',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.READ_MEDIA_VIDEO',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.RECORD_AUDIO',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.VIBRATE',
        'android.permission.WAKE_LOCK',
        'android.permission.WRITE_EXTERNAL_STORAGE',
        'com.openhearth.punctumtemporis.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
      },
      expectStartupMaintenance: false,
      analysisOptionsOverrideRecorded: true,
    ));
