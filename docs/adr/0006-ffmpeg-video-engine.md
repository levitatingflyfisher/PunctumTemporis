# ADR-0006: FFmpeg as the single video engine

- **Status:** Accepted
- **Date:** documenting a decision load-bearing since the first release

## Context

The app's whole point is video: turn a photo into a 1-second clip, trim a
recording, generate a thumbnail, normalize clips shot on different phones to a
common format, concatenate a date range into one montage, burn in a date/location
overlay, and mix background music over the result — sometimes several audio
segments with per-segment offsets and volumes. These operations must produce a
*uniform* output (mismatched resolutions/codecs/sample rates make concat fail or
glitch) and must work on Android and in a browser.

## Decision

Use **FFmpeg** as the one engine for every video operation, behind a thin
`FFmpegService` façade over a platform-twin `FfmpegRunner`
([ADR-0002](0002-platform-twin.md)): `FFmpegKit` (native binary) on Android,
`ffmpeg.wasm` on web.

- **Uniform target:** every clip is normalized to **1080×1920, yuv420p, H.264
  (libx264, CRF 23, preset fast), 30 fps**, with **AAC stereo audio at 44.1 kHz,
  128 kbps** — silent clips get a generated `anullsrc` track so concat always sees
  audio. Non-vertical sources are scaled to fit and padded (letterbox), never
  stretched.
- **Concat** normalizes each input, writes a concat-demuxer list, and re-encodes
  to a single output.
- **Overlay** uses `drawtext` with the text written to a temp file (avoids shell
  quoting/escaping problems with user location strings).
- **Audio mixing** builds a `filter_complex` graph (`atrim`/`adelay`/`volume` per
  segment, then `amix`). The graph builder is a **pure function**
  (`buildMultiTrackFilterGraph` in `ffmpeg_service.dart`) so it is unit-tested
  without invoking FFmpeg.
- Progress is surfaced via FFmpegKit's statistics callback during concat.

## Consequences

- **Buys:** one dependency covers the entire media pipeline on both platforms with
  the same command strings and filter graphs. The pure filter-graph builder is
  directly testable.
- **Costs:** FFmpeg is a large native dependency (a big share of the APK — hence
  `--split-per-abi`, see the README) and a multi-megabyte `.wasm` on web that needs
  cross-origin isolation to run multi-threaded (see
  [how-to/ship-web-pwa.md](../how-to/ship-web-pwa.md)). Re-encoding on concat costs
  CPU/time versus stream-copy, but is required for uniformity.
- **Forecloses:** per-platform native editors (AVFoundation / MediaCodec) — one
  engine, one set of commands, is the deliberate simplification.

## Alternatives considered

- **Platform-native video APIs:** rejected — two implementations to maintain, and
  no shared, testable command layer.
- **Stream-copy concat (no re-encode):** rejected as the default — clips from
  different devices differ in codec/resolution/SAR and concat glitches or fails
  without normalization.
