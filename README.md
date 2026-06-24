# One Second A Day

Capture one second of video every day and compile them into montage videos. Built with Flutter, local-first, no telemetry.

## About

One Second A Day is a free, open-source app for families who want to document life one moment at a time. All data stays on your device — no accounts, no cloud, no tracking. It is developed and maintained by [C3_ORG_NAME], a 501(c)(3) nonprofit building free tools for families.

## Features

### Capture & Organize
- Record 1-second video clips daily via camera or gallery import
- Multi-clip per day support with drag-to-reorder
- Post-capture trimming with duration presets
- Calendar view to browse and manage clips
- Tag system for organizing clips
- GPS capture and reverse geocoding for location metadata
- Face detection and recognition to auto-tag people in clips

### Compile & Share
- Compile date ranges into montage videos with transitions
- Optional background music for compilations
- Date and location overlay (retro CRT style)
- Tag, location, people, and day-of-week filters for compilations
- Quick compile presets (This Week)
- Share clips and compilations via system share sheet

### Search & Filter
- Calendar search/filter panel with tag, location, and people chips
- AND logic across filter categories
- Non-matching days dimmed on calendar for visual clarity

### Data Safety
- ZIP-based backup and restore (clips, thumbnails, faces, metadata)
- Merge or replace restore modes with ID-based dedup
- Backup validation showing clip count, date range, and size

### Stats & Review
- Year-in-Review screen with heatmap, monthly bars, stats grid
- Top locations, tags, and faces summaries
- Streak tracking across date ranges

### Engagement
- Android home screen widget showing streak count and today's capture status
- 3-page onboarding flow for new users
- Streak milestone celebrations at 7, 30, 50, 100, 200, and 365 days
- Daily reminder notifications with configurable time

### Visual Style
- Retro/CRT aesthetic with pixel fonts and scanline overlay
- Custom app icon (hourglass + snowflake)

## Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Android | Stable | `flutter build apk --split-per-abi` |
| iOS (PWA) | Beta | Install via Safari "Add to Home Screen" — no App Store required |

### iOS PWA

The web build targets iOS Safari via Progressive Web App. Users visit the URL in Safari, tap "Add to Home Screen," and get a full-screen offline app with all video data stored on-device using the browser's Origin Private File System (OPFS).

Architecture: platform-twin pattern via Dart conditional exports (`lib/platform/`). Native-only packages are replaced with web equivalents; video processing uses ffmpeg.wasm. All data stays on-device.

Features gracefully disabled on web: face recognition, push notifications, home screen widget.

## Setup

### Requirements

- Flutter SDK >=3.3.0
- Android device/emulator

### Face Recognition Model

Face recognition requires a MobileFaceNet TFLite model. Place it at:

```
assets/models/mobilefacenet.tflite
```

This file is not included in the repo due to size. You can obtain a MobileFaceNet model from open-source model repositories (typically 5-20MB, outputs 192-dimensional embeddings).

### Build & Run

```bash
flutter pub get
flutter run
```

### Build APK

Always build split APKs to avoid bloated output (~98-128MB per ABI vs ~289MB fat APK):

```bash
flutter build apk --split-per-abi
```

## Architecture

```
lib/
  main.dart                          # App entry, onboarding gate
  models/clip.dart                   # Clip and Compilation data models
  screens/
    calendar_screen.dart             # Main calendar UI + search/filter
    video_capture_screen.dart        # Record video clips
    gallery_import_screen.dart       # Import clips from gallery
    clip_preview_screen.dart         # Preview, trim, tag, share clips
    day_view_screen.dart             # Multi-clip day view + reorder
    compilation_screen.dart          # Compile clips into montage
    year_review_screen.dart          # Year-in-Review stats
    settings_screen.dart             # App settings
    backup_restore_screen.dart       # Backup, restore, share UI
    onboarding_screen.dart           # First-launch onboarding
  services/
    ffmpeg_service.dart              # FFmpeg video operations
    storage_service.dart             # Metadata persistence + prefs
    backup_service.dart              # ZIP backup/restore logic
    face_service.dart                # Face detection + embeddings
    notification_service.dart        # Daily reminder notifications
  utils/
    location_util.dart               # GPS + reverse geocoding
  widgets/
    crt_effects.dart                 # RetroCard, RetroButton, CrtOverlay
    app_theme.dart                   # Theme, fonts, colors
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `ffmpeg_kit_flutter_new` | Video processing (trim, concat, overlay) |
| `google_mlkit_face_detection` | Face detection |
| `tflite_flutter` | MobileFaceNet face embeddings |
| `geolocator` | GPS location capture |
| `flutter_local_notifications` | Daily reminders |
| `archive` | ZIP backup/restore |
| `share_plus` | System share sheet |
| `home_widget` | Android home screen widget |
| `photo_manager` | Gallery access for import |
| `google_fonts` | Retro pixel fonts |

## Testing

```bash
flutter test
```

69 tests covering backup logic, clip reordering, trim bounds, calendar filtering, year-in-review stats, notification scheduling, and layout regressions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License. See [LICENSE](LICENSE) for details.

## About [C3_ORG_NAME]

[C3_ORG_NAME] is a 501(c)(3) nonprofit dedicated to strengthening families through policy research, education, and free public tools.
