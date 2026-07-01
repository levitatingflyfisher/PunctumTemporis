# Changelog

All notable changes to this project will be documented in this file.

## [1.5.0] - 2026-07-26

### Added
- Backups now carry your montage videos under `compilations/` — ON by
  default (montages are the point of the app), with an "Include montage
  videos" switch next to the size estimate for when size matters. The
  verified receipt reports the montage files actually aboard; a montage
  whose file is unreadable at pack time is skipped honestly instead of
  failing the backup.
- Every new montage saves its recipe — the clip-audio level and each
  music segment with its timing and volume — so re-opening one seeds the
  compile controls exactly as you left them, on any device the backup
  lands on. (Montages made before this release have no recipe and open
  with the current controls, as before.)
- Restored montage files are extracted into the app's own `compiled/`
  dir and their rows re-pointed there, so montages made on a previous
  install play again after a device or app-id migration.

### Fixed
- Opening a montage whose video file isn't on this device now shows a
  quiet inline notice (the gallery copy usually survives, and COMPILE
  rebuilds it from the clips) instead of a raw video-player error
  snackbar — the post-migration failure a restored diary used to hit.
- Restored compilation paths are now pinned into the app's own compiled
  dir the way clip paths always were, so a crafted backup can no longer
  aim share/delete/next-backup file operations at arbitrary paths
  through a compilation row.
- A gallery-scanner hiccup after saving a montage no longer surfaces as
  an error — the row is already saved; the refresh is a courtesy.
- Home-screen widget refresh failures no longer escape as unhandled
  async errors: the plugin calls return futures, and each now carries
  its own error handler.

## [1.4.0] - 2026-07-22

### Added
- Previous snapshots: before every restore the app automatically saves a
  snapshot of your journal index AND settings (keep-10) — restore, or roll
  one back, from the Backup & Restore screen. Video files are never
  deleted by a restore, so rolling back covers everything a restore can
  change.
- Restores are refused (nothing touched) if the safety snapshot cannot be
  saved — fail-closed by design.
- Backups now include your settings (theme, reminders, pinned tags,
  milestones — an explicit allowlist; internal flags never travel); older
  backups without them still restore fine, and older app versions simply
  ignore the new entry.
- Every backup verifies itself by read-back before reporting success —
  the receipt counts the clip files actually inside the archive.
- Silent freshness snapshots: when your newest journal snapshot is more
  than 7 days old (or you have none), the app quietly saves one right
  after launch. No nag, no badge — it just happens, so there is always a
  recent rollback point even if you never open Backup & Restore.

### Fixed
- New vault snapshots stay readable by OLDER app versions: they now carry
  the legacy `{snapshotVersion, metadata, settings}` keys alongside the
  new envelope keys, because the old shipped parser has no envelope
  branch and would have written the envelope wrapper over the journal
  index as if it were metadata.
- The replace-mode confirmation no longer promises settings replacement
  for older (v1) backups that carry no settings — it now says your
  current settings stay as they are.

### Changed
- The replace-all warning now tells the truth: a rollback snapshot exists,
  so "cannot be undone" is gone.
- The replace-mode confirmation now says exactly what happens: the journal
  index and settings are replaced, clips missing from the backup stop
  appearing in the app, and their video files stay on your device — a
  restore never deletes clip files, so "REPLACE ALL DATA?" overstated it.

### Internal
- The Hearth palette now reads its canonical colors from the shared
  openhearth_design token package instead of hard-coded hex values.
  Every swapped value is byte-identical, so nothing looks different;
  two PT-local dark surfaces intentionally stay as literals because
  they do not match any canonical token.
- Vault snapshots are now wrapped in the fleet-standard BackupEnvelope
  (`{app, schemaVersion, createdAt, payload}`) via a new
  SnapshotSerializer, gaining a creation stamp and wrong-app /
  future-schema rejection on restore. Both legacy snapshot shapes (the
  v2 composite and the original raw metadata map) keep restoring —
  existing rollback points are never orphaned.
- The fleet conformance suite is wired in
  (`test/fleet_conformance_test.dart`): style tokens, backup envelope,
  size budgets (`budgets.json`, baseline+5% ratchet), the exact
  nine-permission Android surface, and CI/test-harness canon are now
  tests that can fail, with PT's deliberate divergences recorded in one
  place. `test/flutter_test_config.dart` re-synced to the canonical
  fleet template (goldens unchanged, byte-identical).
- CI: all three workflows pinned a Flutter version that has never
  existed (`3.44.x`); they now pin the real fleet toolchain `3.38.7`
  and clone the sibling path-dep packages so `pub get` can actually
  resolve.
- Removed unused dependencies `image_picker` and `permission_handler`
  (zero references; all Android permissions are hand-declared in the
  manifest, so the permission surface is unchanged).

### Fixed
- Streaks are no longer miscounted across a daylight-saving change: the
  current-streak walk and longest-streak scan now use calendar-day
  arithmetic (UTC-midnight subtraction) instead of elapsed-hours/24,
  which could skip a day or split a real streak on the transition night.
  Stored day keys are unchanged.

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
