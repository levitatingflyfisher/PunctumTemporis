# How-to: build & run

Task-oriented. Assumes a working Flutter toolchain (SDK `>=3.3.0`; CI pins
`3.44.x` stable).

## Run the app in development

```bash
flutter pub get
flutter run          # on a connected Android device or emulator
```

The app is fully usable immediately — no account, no server. On first launch you
get a 3-page onboarding, then the calendar.

## Enable face recognition (optional)

Face detection/recognition needs a MobileFaceNet TFLite model that is **not**
shipped in the repo (size + licensing). Without it, the face system is inert and
everything else works.

1. Obtain a MobileFaceNet model (a 112×112 input, 192-dim embedding model;
   typically 5–20 MB) from an open model source.
2. Place it at:

   ```
   assets/models/mobilefacenet.tflite
   ```

3. Re-run. `FaceService.initialize()` loads it; `main.dart` logs whether face
   recognition is available. `*.tflite` is git-ignored — do not commit a model.

## Run the tests

```bash
flutter test                 # full suite (30 test files, incl. goldens)
flutter test test/services   # a subset
flutter analyze              # lint (analysis_options.yaml → flutter_lints)
```

**Golden layout tests** live in `test/visual/` with images under
`test/visual/goldens/`. They render retro widgets at multiple widths and text
scales to catch overflow regressions. If you *intentionally* change a widget's
look:

```bash
flutter test --update-goldens
# then review the image diff before committing
```

## Build release APKs

Always split per ABI. FFmpeg makes a fat APK very large; split APKs are far
smaller per install.

```bash
flutter build apk --split-per-abi --release
# outputs: build/app/outputs/flutter-apk/app-<abi>-release.apk
```

An app bundle is also produced in CI (`flutter build appbundle --release`) via
`.github/workflows/release-android.yml` (triggered by a version tag).

## Build the web PWA

```bash
flutter build web --release --base-href "/<repo-or-path>/"
# outputs: build/web/
```

Serving the web build correctly (OPFS, and the cross-origin isolation ffmpeg.wasm
needs) has its own guide — see [ship-web-pwa.md](ship-web-pwa.md).
