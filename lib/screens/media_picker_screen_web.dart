import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/crt_effects.dart';

// Web stub: MediaPickerScreen is not used on web.
// Gallery import on web goes through GalleryImportScreen (file_picker).
// This stub exists only so conditional exports compile.

// Keep public types that tests may reference.
class MediaPickerItem {
  final int? assetIndex;
  final bool matchesTarget;
  final String? separatorLabel;
  final bool isTargetAsset;
  final bool isNearbyAsset;

  const MediaPickerItem({
    this.assetIndex,
    this.matchesTarget = false,
    this.separatorLabel,
    this.isTargetAsset = false,
    this.isNearbyAsset = false,
  });
}

MediaPickerItem getMediaPickerItemAt({
  required int index,
  required int targetAssetCount,
  int nearbyAssetCount = 0,
  required int otherAssetCount,
  required String noMediaLabel,
  required bool hasMore,
}) {
  return const MediaPickerItem();
}

int getMediaPickerItemCount({
  required int targetAssetCount,
  int nearbyAssetCount = 0,
  required int otherAssetCount,
  required bool hasMore,
}) => 0;

class MediaPickerScreen extends StatelessWidget {
  final String targetDate;
  final bool crtEnabled;

  const MediaPickerScreen({
    super.key,
    required this.targetDate,
    this.crtEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Text(
          'NOT AVAILABLE ON WEB',
          style: AppTheme.pixelFont(fontSize: 14),
        ),
      ),
    );
  }
}
