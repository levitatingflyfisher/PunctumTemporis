# Architecture Decision Records

Lightweight [Nygard-format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
records of the choices a future maintainer would otherwise re-litigate. Each is
**Status · Context · Decision · Consequences**. Reality wins over these docs — if
the code has moved, fix the ADR.

| # | Decision | Status |
|---|---|---|
| [0001](0001-local-first-no-accounts.md) | Local-first, no accounts, no telemetry — nothing leaves the device at runtime | Accepted |
| [0002](0002-platform-twin.md) | One codebase, native + web, via compile-time platform twins | Accepted |
| [0003](0003-json-metadata-no-db.md) | Persist to a single `metadata.json` file, not a database | Accepted |
| [0004](0004-on-device-face-crop.md) | Store face references cropped to the detected box, on device | Accepted |
| [0005](0005-untrusted-backup-hardening.md) | Treat a restored backup ZIP as untrusted input | Accepted |
| [0006](0006-ffmpeg-video-engine.md) | FFmpeg (FFmpegKit native / ffmpeg.wasm web) as the single video engine | Accepted |
