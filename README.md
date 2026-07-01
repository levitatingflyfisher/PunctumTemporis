# Punctum Temporis

Capture one second of video every day and compile them into montage films. Built
with Flutter — **local-first, no accounts, no telemetry**. The private, offline,
own-your-footage alternative to a subscription cloud video diary.

> **Vision:** One second a day — and it never leaves your hands. Your family's
> faces, places, and days are captured, face-matched, and compiled *entirely on
> your device*. No account, no upload, no subscription.
> See **[VISION.md](VISION.md)** for the north star and
> **[docs/](docs/README.md)** for the full documentation.

## About

Punctum Temporis is a free, open-source video journal for families who want to
document life one moment at a time. All data stays on your device — no accounts, no
cloud, no tracking. It records a daily one-second clip, recognizes faces on device,
and stitches date ranges into montage films with FFmpeg. MIT-licensed.

*(The internal Dart package is still named `one_second_a_day` — legacy history.
The product is Punctum Temporis.)*

## Features

### Capture & organize
- Record 1-second clips daily via camera, photo, or gallery import
- Multi-clip per day with drag-to-reorder
- Post-capture trimming with duration presets
- Calendar view to browse and manage clips
- Tags for organizing clips
- GPS capture with **offline** reverse-geocoding (city-level, no network)
- On-device face detection + recognition to auto-tag people

### Compile & share
- Compile date ranges into montage films
- Optional background music (single or multi-track, timeline-placed)
- Date and location overlay
- Tag, location, people, and day-of-week filters for compilations
- Share clips and compilations via the system share sheet

### Search & filter
- Calendar filter panel with tag, location, and people chips (AND logic)
- Non-matching days dimmed for visual clarity

### Data safety
- ZIP backup and restore (clips, thumbnails, cropped faces, metadata)
- Merge or replace restore modes with ID-based dedup
- Backup validation showing clip count, date range, and size
- Restore hardened against zip bombs, ZIP Slip, and metadata path traversal

### Stats & engagement
- Year-in-Review: heatmap, monthly bars, stats grid, top locations/tags/faces
- Streak tracking and milestone celebrations (7, 30, 50, 100, 200, 365 days)
- Android home-screen widget (streak + today's status)
- Daily reminder notifications with a configurable time
- 3-page onboarding for new users

### Visual style
- Three visual styles — **Retro** (CRT/pixel aesthetic), **Modern** (Material 3),
  **Hearth** (warm OpenHearth palette, default); all fonts bundled

## Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Android | Stable | `flutter build apk --split-per-abi` |
| Web / iOS (PWA) | Beta | Installable from a URL; on iOS via Safari "Add to Home Screen" — no App Store |

Face recognition, push notifications, and the home-screen widget are Android-only;
on web they are disabled by design. See
[docs/how-to/ship-web-pwa.md](docs/how-to/ship-web-pwa.md).

## Setup

### Requirements
- Flutter SDK `>=3.3.0` (CI pins `3.44.x`)
- An Android device/emulator (for the native app)

### Face recognition model (optional)
Face recognition needs a MobileFaceNet TFLite model, not shipped in the repo due
to size/licensing. Place one at:

```
assets/models/mobilefacenet.tflite
```

It should take a 112×112 input and output a 192-dim embedding (typically 5–20 MB).
Without it, face features are simply off and everything else works.

### Build & run
```bash
flutter pub get
flutter run
```

### Build APK
Always build split APKs — FFmpeg makes a fat APK very large:
```bash
flutter build apk --split-per-abi
```

Full dev/build/test guide: [docs/how-to/build-and-run.md](docs/how-to/build-and-run.md).

## Architecture

A layered Flutter app — plain `StatefulWidget` state with a single injected
`StorageService` (no Riverpod/Drift), JSON metadata persistence, and a
**platform twin** so one codebase runs native and web.

```
lib/
  main.dart              # entry, onboarding gate, StorageService injection
  models/                # Clip, Compilation, AudioSegment (domain)
  services/              # storage, ffmpeg, face, face_crop, backup, geocoder, notifications
  platform/              # native ⟷ web twins (file storage, ffmpeg, faces, notifications)
  screens/               # calendar, capture, import, compile, year-review, settings, ...
  widgets/               # crt_effects (retro), thumbnails, dialogs
  theme/                 # app_theme (retro / modern / hearth)
  utils/                 # date + location helpers
```

Details, diagrams, and the module map: **[docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md)**.
Decision rationale: **[docs/adr/](docs/adr/)**.

## Key dependencies

| Package | Purpose |
|---------|---------|
| `ffmpeg_kit_flutter_new` | Video processing (native) |
| `google_mlkit_face_detection` | On-device face detection |
| `tflite_flutter` | MobileFaceNet face embeddings |
| `image` | Crop face thumbnails to the detected box (privacy) |
| `geolocator` | GPS capture |
| `flutter_local_notifications` | Daily reminders |
| `archive` | ZIP backup/restore |
| `share_plus` | System share sheet |
| `home_widget` | Android home-screen widget |
| `photo_manager` | Gallery access for import |

## Testing

```bash
flutter test
```

30 test files covering backup safety, clip reorder/trim, calendar filtering,
year-in-review stats, notification scheduling, the face-crop privacy step, the
FFmpeg filter-graph builder, offline-font bundling, and golden layout regressions.

## Documentation

Organized [Diátaxis](https://diataxis.fr/)-style — start at
**[docs/README.md](docs/README.md)**. Highlights:
[Vision](VISION.md) · [Architecture](docs/architecture/OVERVIEW.md) ·
[Pipeline reference](docs/reference/pipeline.md) ·
[Privacy model](docs/privacy-model.md) · [White paper](docs/whitepaper.md) ·
[AGENTS.md](AGENTS.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License. See [LICENSE](LICENSE) for details.
