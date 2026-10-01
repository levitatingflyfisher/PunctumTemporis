import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// The one-time line before the first location prompt: on the capture
/// screen, above Save, while location capture is on and no save has asked
/// yet. The OS prompt used to fire mid-save with nothing before it (audit
/// finding 11).
class LocationNotice extends StatelessWidget {
  const LocationNotice({super.key, required this.storageService});

  final StorageService storageService;

  static const text =
      'Saving adds the nearest town to this clip, looked up on this phone. '
      'Your phone will ask for location once; you can say no, or turn it '
      'off in Settings.';

  @override
  Widget build(BuildContext context) {
    if (!storageService.getCaptureLocation() ||
        storageService.getLocationNoticeShown()) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1, right: 8),
            child: Icon(Icons.location_on_outlined,
                size: 18, color: Colors.white),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTheme.monoFont(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
