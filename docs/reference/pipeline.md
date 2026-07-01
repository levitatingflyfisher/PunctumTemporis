# Reference: the capture → compile and face-crop pipelines

Precise, information-oriented reference for the two pipelines at the heart of
Punctum Temporis. Everything here is grounded in
`lib/platform/ffmpeg_runner_native.dart`, `lib/platform/face_service_impl.dart`,
`lib/services/face_crop.dart`, and `lib/services/storage_service.dart`. The web
twin (`ffmpeg_runner_web.dart`, ffmpeg.wasm) mirrors the native operations; face
recognition is disabled on web (stub twin).

---

## 1. Capture → stored `Clip`

Three entry points produce a clip, all converging on the same normalized MP4 plus
a thumbnail plus (native) face tagging.

| Source | Screen | FFmpeg step |
|---|---|---|
| Record video | `video_capture_screen.dart` | trim / normalize to target |
| Take photo | `photo_capture_screen.dart` | `photoToVideo` (still → N-second clip) |
| Import from gallery | `gallery_import_screen*.dart`, `media_picker_screen*.dart` | `extractSegment` (video) or `photoToVideo` (image) |

After the clip exists:

1. **Thumbnail** — `generateThumbnail` grabs one frame at `t = 0.5s`, scaled to
   width 320 (`-vf scale=320:-1`, `-q:v 2`).
2. **Face tagging (native only)** — `FaceService.detectAndEmbed(thumbnailPath)`
   → match against `knownPeople` → recognized names go into `Clip.detectedFaces`
   (see §3).
3. **Location (optional)** — GPS is reverse-geocoded **offline** to `"City, CC"`
   via `OfflineGeocoder` (bundled `assets/data/cities.csv`, brute-force nearest
   city by haversine). No network call.
4. **Persist** — the `Clip` is added to `StorageService`'s in-memory map and
   `metadata.json` is rewritten.

### The uniform target format

Every normalization/trim path targets the **same** vertical format so that
concatenation never sees a mismatch:

| Property | Value |
|---|---|
| Resolution | **1080 × 1920** (portrait), aspect-preserving scale + centered pad |
| Pixel format | `yuv420p` |
| Video codec | `libx264`, `-crf 23`, `-preset fast` |
| Frame rate | `30` |
| Audio codec | `aac`, `44100` Hz, stereo (`-ac 2`), `128k` |
| SAR | `setsar=1` |

Silent sources get a generated silent track (`-f lavfi -i anullsrc=r=44100:cl=stereo`)
so downstream steps can always assume an audio stream exists.

### FFmpeg operation catalog

All live in `FfmpegRunner` (native) / its web twin, fronted by `FFmpegService`.
Each returns the output path on success or `null` on failure (fail-safe — the
caller keeps the user's source).

| Method | Purpose | Notable flags |
|---|---|---|
| `photoToVideo(img, out, duration)` | still image → clip | `-loop 1`, `anullsrc`, scale+pad to 1080×1920, `-t duration` |
| `extractSegment(in, out, start, duration)` | pull a segment from a video | `-ss start -t duration`, normalize |
| `trimVideo(in, out, duration)` | trim to length | `-t duration`, normalize |
| `generateThumbnail(video, out)` | one JPEG frame | `-ss 0.5 -vframes 1 -q:v 2 -vf scale=320:-1` |
| `hasAudioStream(video)` | probe for audio | FFprobe stream scan |
| `getVideoDuration(video)` | duration in seconds | FFprobe |
| `normalizeClip(in, out)` | conform to target format | branches on `hasAudioStream`; adds silent track if none |
| `addSilentAudio(in, out)` | attach a silent track | `-c:v copy` + `anullsrc` |
| `concatenateClips([...], out, onProgress)` | montage | normalize each → concat demuxer (`-f concat -safe 0`) → re-encode |
| `addDateOverlay(in, out, dateText, ...)` | burn in date/location | `drawtext` from a **temp text file**; positions `top/bottom-left/right` |
| `addBackgroundMusic(video, music, out, ...)` | one music track | `filter_complex` two-input `amix` with per-input `volume` |
| `addMultipleAudioTracks(video, [seg], out, ...)` | multi-segment audio | `filter_complex` from `buildMultiTrackFilterGraph` |
| `cancel()` | abort the running session | `FFmpegKit.cancel()` |

### Compilation flow

```
pick date range + filters (tag / location / people / weekday)
   → collect matching clips in date order
   → normalizeClip each (uniform format)
   → concat demuxer list → concatenateClips → single MP4
   → optional addDateOverlay (per-clip date + location)
   → optional addBackgroundMusic / addMultipleAudioTracks
   → written to Movies/OneSecondADay/compilations/  (public, shareable)
```

The multi-track graph is built by the **pure function**
`buildMultiTrackFilterGraph(segments, originalVolume, videoDuration)` in
`ffmpeg_service.dart` — per segment it emits
`atrim`(→`asetpts=PTS-STARTPTS`)→optional `adelay`→`volume`, then a final
`amix=inputs=N+1:duration=longest:dropout_transition=2`. It is unit-tested without
invoking FFmpeg (`test/services/ffmpeg_service_test.dart`).

---

## 2. Face pipeline (detect → embed → match), on device

Native only (`face_service_impl.dart`); the web twin returns no faces. Requires a
user-supplied `assets/models/mobilefacenet.tflite` — absent it, `isAvailable` is
false and every call no-ops.

**Detector** (`google_mlkit_face_detection`):
`FaceDetectorMode.accurate`, `enableLandmarks: true`, `minFaceSize: 0.15`.

**Per detected face → embedding:**

1. Read the image bytes; decode to a `ui.Image`.
2. Clamp the ML Kit bounding box to image bounds.
3. Sample-crop-and-resize the box region to **112 × 112** (MobileFaceNet input),
   reading raw RGBA and mapping destination pixels back to source coordinates.
4. Normalize each channel to **[-1, 1]** (`value / 127.5 - 1.0`).
5. Run the interpreter → a **192-dimensional** embedding vector.

**Matching** (`findBestMatch`): cosine similarity between the new embedding and
each stored reference embedding in `knownPeople`; the best match above the
**threshold (default 0.6)** wins, returning `(name, score)`; below threshold →
`null` (unknown). Cosine similarity guards zero-norm and length-mismatch inputs by
returning `0`.

---

## 3. Face-crop privacy step (what actually gets stored)

Recognizing a face and *storing a reference image* for a named person are
separate. The reference image is **cropped to the face**, never the whole frame —
see [ADR-0004](../adr/0004-on-device-face-crop.md).

`StorageService.saveFaceImage(name, sourceImagePath, boundingBox)`:

```
read source bytes
  → cropFaceJpg(bytes, box):
        decode → clamp box to image bounds → copyCrop → encodeJpg
  → if crop succeeded:  write faces/<name>.jpg  (just the face)
    else (undecodable): copyFile whole source   (fail-safe fallback)
```

`cropFaceJpg` (`lib/services/face_crop.dart`) precisely:

- `x = box.left`  clamped to `[0, width-1]`
- `y = box.top`   clamped to `[0, height-1]`
- `w = box.width` clamped to `[1, width - x]`
- `h = box.height` clamped to `[1, height - y]`
- returns `null` on any decode failure (bytes can be malformed *and* `decodeImage`
  can throw) so the caller can fall back rather than lose the face.

The clamp exists because **ML Kit face boxes routinely extend past the image
edges**; without it a crop would throw. Behavior is locked by
`test/services/face_crop_test.dart`.

The net privacy property: `faces/*.jpg` contains cropped faces, not rooms — and
because inference is on device and geocoding is offline, no part of this pipeline
sends data off the device (see [privacy-model.md](../privacy-model.md)).

---

## 4. Platform-twin summary for these pipelines

| Capability | Native (Android) | Web (PWA) |
|---|---|---|
| Video engine | `FFmpegKit` (native binary) | `ffmpeg.wasm` (needs COOP/COEP — see how-to) |
| File I/O | `dart:io` filesystem | Origin Private File System (OPFS) |
| Face detect / recognize | ML Kit + MobileFaceNet | **disabled** (stub) |
| Compilation output | `Movies/OneSecondADay/compilations/` | browser download |
