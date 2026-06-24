# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0] - 2026-03-20

### Added
- Calendar: TODAY shortcut appears when browsing past months
- Calendar: last-viewed date highlighted with secondary border
- Compilation: season preset label shows season name and months (e.g., SPRING MAR-MAY)
- Date range picker: LAST WEEK preset
- Date range picker: scroll fade hints at additional presets

### Fixed
- Calendar: filter icon changed to tune icon with active badge for clarity
- Calendar: future dates hidden (no longer shown as dim numbers)
- Gallery import: target date shown throughout import flow; cancel button added
- Backup restore: cancel button added to progress UI
- Capture options: removed misleading "1 second" subtitle text
- Capture button: more clearance from stats footer

## [1.2.0] - 2026-03-10

### Added
- Gallery picker: ±1 day NEARBY row surfaces Signal/late-EXIF photos automatically
- Gallery picker: ← → date shift buttons for photos off by more than 1 day
- Compilation date picker: fixed height (no more resize between months)
- Compilation date picker: tap month/year header to jump directly to any month
- Compilation date picker: THIS MONTH, LAST MONTH, THIS YEAR, LAST YEAR, ALL TIME presets
- Tag chips: × icon makes removal visible and obvious
- Location edit: CLEAR button to remove location from a clip
- Tag/location chips: long-press to pin (keeps chip available even when no clips use it)
- Day view: inline reorderable clip list with always-visible drag handles
- Day view: sequence number badges (1, 2, 3...) on multi-clip thumbnails
- Compilation: backgrounding shows toast; resuming refreshes session status

### Fixed
- Compilation UI no longer freezes after returning from another app

## [1.1.0] - 2026-01-19

### Added
- iOS PWA support via Safari "Add to Home Screen" (no App Store required)
- Web platform: OPFS file storage, ffmpeg.wasm video processing
- Web gallery import supporting both images and video files
- Progressive Web App manifest with offline support via service worker

## [1.0.0] - 2026-01-19

### Initial public release

- Daily 1-second video capture via camera, photo, or gallery import
- Multi-clip per day with drag-to-reorder
- Post-capture trimming with duration presets (1–5 seconds)
- Calendar view with month grid and search/filter panel
- Tag system for organizing clips
- GPS capture and offline reverse geocoding for location metadata
- Face detection and recognition (MobileFaceNet) to auto-tag people
- Compile date ranges into montage videos with optional background music
- Date and location overlay (retro CRT style)
- Compilation filters: tag, location, people, day-of-week
- ZIP-based backup and restore with merge/replace modes
- Year-in-Review: heatmap, monthly bars, stats, top locations/tags/faces
- Android home screen widget showing streak and today's status
- Daily reminder notifications with configurable time
- 3-page onboarding flow
- Streak milestone celebrations at 7, 30, 50, 100, 200, and 365 days
- Retro/CRT aesthetic with pixel fonts and scanline overlay
- 69 unit and widget tests
