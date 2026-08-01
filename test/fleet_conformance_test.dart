// PunctumTemporis' recorded fleet-standardization posture. Every deliberate
// divergence from fleet canon is a field HERE, not an unexplained delta:
//  * expectStartupMaintenance: false — PT drives the vault (freshness
//    snapshot + prune) from its own storage service in its own idiom
//    rather than the package's runStartupMaintenance hook.
//  * analysisOptionsOverrideRecorded — PT's analysis_options adds
//    avoid_print on top of the stock template (deliberately tighter).
import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

void main() => runFleetConformance(const FleetAppConfig(
      appId: 'punctumtemporis',
      // Bundles its own type, so nothing falls back to a web font — a
      // character the bundled families cannot draw is a box on a
      // real phone. C7 sweeps lib/ for any.
      checks: FleetAppConfig.withBundledFonts,
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
