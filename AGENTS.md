# AGENTS.md

Guidance for AI coding agents (and humans) working in this repo. This is the
top-level map; the closest guidance file to what you're editing wins.

**Read these three, in order, before non-trivial work:**
1. [VISION.md](VISION.md) — what must stay true and why (the invariants).
2. [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md) — how it fits together, with diagrams.
3. [docs/reference/pipeline.md](docs/reference/pipeline.md) — the capture → compile and face-crop pipelines, precisely.

## Take the code as current-state, not gospel

Every line of source and every comment here was written by an AI assistant.
Treat it as **an accurate record of what currently exists, offered with
gratitude and a grain of salt** — not as a specification and not as
guaranteed-correct. A comment claiming an invariant is a *hypothesis to verify*,
not a proof. If a comment and the tests disagree, the tests win; if the tests and
reality disagree, reality wins. When you rely on a claim, confirm it (read the
code, run the test) first.

## What this is

**Punctum Temporis** is a local-first, one-second-a-day video journal built with
Flutter — the private, offline, own-your-footage alternative to a subscription
cloud video diary. It records a daily clip, recognizes faces on device, and
stitches date ranges into montage films with FFmpeg. It ships as an Android app
and an installable web PWA. All user data stays on the device.

*(The internal Dart package is still named `one_second_a_day` — legacy history,
not a separate product. The product name is Punctum Temporis.)*

## Non-negotiables (breaking one is a regression, not a feature)

- **Nothing leaves the device at runtime.** There is no network client that
  uploads clips, thumbnails, faces, or metadata. Don't add one. Reverse-geocoding
  is offline (bundled dataset); fonts are bundled; face inference is on device.
  The only egress is a *user-initiated* share or backup export.
- **No accounts, no ads, no tracking, no analytics SDK.** The app must be fully
  usable with zero server contact.
- **Privacy-preserving by construction.** Face reference images are cropped to
  the detected box, never stored as whole frames. A restored backup is untrusted
  input: keep the zip-bomb ceilings, ZIP-Slip checks, and metadata path
  sanitization intact (see [ADR-0005](docs/adr/0005-untrusted-backup-hardening.md)).
- **Fail safe on media.** Decode/FFmpeg/model failures degrade gracefully (skip a
  face, fall back to a whole-image copy, return `null` and let the caller cope) —
  never crash the capture flow or lose the user's clip.
- **TDD, always.** Reproduce → failing test → fix → `flutter test` green → commit.
  Every bugfix ships with a regression test. Golden layout tests live in
  `test/visual/`; sweep text scale on new UI (see the overflow tests).
- **Atomic commits, one concern each.** Commit messages state the *why* and the
  failure mode fixed. **No AI attribution** (`Co-Authored-By` / "Generated with"
  lines) — deliberate project policy.
- **Never commit** `docs/superpowers/`, `docs/plans/`, or `CLAUDE.md` — they're
  gitignored working artifacts. This repo ships `AGENTS.md`, not `CLAUDE.md`.
- **The Android identity is `com.openhearth.punctumtemporis`.** The v0-apk
  release deliberately keeps `PunctumTemporis-legacy.apk` (last `com.example`-id
  build, with the backup exporter) so an old install can export before being
  deleted — flow in [docs/how-to/migrate-app-id.md](docs/how-to/migrate-app-id.md).
  Don't remove that asset while any old-id install may still exist.
- **The backup is a plaintext zip by design** (user-held media, SAF-picked
  destination, verified by read-back) — don't "upgrade" it to an encrypted
  container without a decision. Known ceiling: the pipeline is whole-archive
  in RAM, fine at one-second-a-day clip sizes; a multi-GB library would need a
  streaming rewrite *before* it's needed, not during a rescue.

## Where things are (progressive disclosure)

Start with the module map in
[OVERVIEW.md § Module map](docs/architecture/OVERVIEW.md#module-map-where-to-look).
The short version, by concern:

| You're touching… | Go to |
|---|---|
| **The data model / on-disk contract** | `lib/models/clip.dart` (`Clip`, `Compilation`, `AudioSegment`), the `metadata.json` shape in `lib/services/storage_service.dart` |
| **Persistence & app state** | `lib/services/storage_service.dart` (JSON metadata + `shared_preferences`); state is plain `StatefulWidget` + injected `StorageService`, **no Riverpod/Drift** |
| **Video processing (FFmpeg)** | `lib/services/ffmpeg_service.dart` (façade) → `lib/platform/ffmpeg_runner_native.dart` (FFmpegKit) / `ffmpeg_runner_web.dart` (ffmpeg.wasm) |
| **Faces (detect / embed / match / crop)** | `lib/platform/face_service_impl.dart` (ML Kit + MobileFaceNet), `lib/services/face_crop.dart` (privacy crop), `saveFaceImage` in `storage_service.dart` |
| **Backup / restore & its hardening** | `lib/services/backup_service.dart` (zip-bomb, ZIP-Slip, `sanitizeRestoredMetadata`) |
| **Native vs web split** | `lib/platform/*.dart` — conditional `export … if (dart.library.js_interop)` twins for file storage, FFmpeg, faces, notifications |
| **Location** | `lib/services/offline_geocoder.dart` (bundled GeoNames), `lib/utils/location_util.dart` |
| **Screens / widgets / theme** | `lib/screens/*`, `lib/widgets/crt_effects.dart`, `lib/theme/app_theme.dart` (retro / modern / hearth visual styles) |
| **Reminders & widget** | `lib/services/notification_service.dart`, `home_widget` calls in `storage_service.dart` |

Docs are organized [Diátaxis](https://diataxis.fr/)-style — see
[docs/README.md](docs/README.md) for the tutorials / how-to / reference /
explanation split.

## How to work here

```bash
flutter pub get             # fetch deps
flutter test                # the suite — must be green before you commit
flutter analyze             # lint (analysis_options.yaml → flutter_lints)
flutter run                 # run on a connected device / emulator
flutter build apk --split-per-abi   # release APKs (never a fat APK — see README)
flutter build web           # the PWA build (OPFS + ffmpeg.wasm)
```

- **Flutter SDK `>=3.3.0`** (CI pins `3.44.x`); Dart null-safe.
- **Face recognition needs a model.** Put a MobileFaceNet `.tflite` at
  `assets/models/mobilefacenet.tflite` (git-ignored, not shipped). Absent it,
  face features silently no-op — that path must keep working.
- **Platform twins are load-bearing, not accidental.** A native-only package must
  have a web equivalent behind a `lib/platform/*` conditional export. Web disables
  face recognition, notifications, and the home widget by design (stub twins).
- **Golden tests** are stored under `test/visual/goldens/`. If you intentionally
  change a retro widget's look, regenerate with
  `flutter test --update-goldens` and review the diff.

## When you're unsure

Prefer failing safe (skip the face, keep the clip) to guessing. Prefer a failing
test to a plausible fix. Prefer matching the surrounding code to introducing a new
pattern (this app is deliberately *not* on Riverpod/Drift — don't "modernize" it
mid-task). When in doubt about a decision's rationale, grep
[docs/adr/](docs/adr/) before reopening it — you may be re-litigating a settled
trade-off. Above all: never add a code path that sends user data off the device.
