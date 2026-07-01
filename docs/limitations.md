# Limitations

Read this before adopting. The [scorecard](../VISION.md#honest-scorecard--built-vs-aspirational)
says what's real; this page says what the app **does not do**, so no one is
surprised. Some of these are deliberate invariants; others are honest gaps.

## By design (invariants, not gaps)

- **No cloud, no accounts, no sync.** The app is single-device. There is no login,
  no cloud backup, no cross-device continuity. Moving your diary to a new phone
  means exporting a backup ZIP and restoring it. This is the point of the app, not
  a missing feature ([ADR-0001](adr/0001-local-first-no-accounts.md)).
- **No ads, no analytics, no telemetry.** We collect nothing, so we can't offer
  "insights" derived from aggregate usage.
- **Location is city-level only.** By design coarse and offline — never a street
  address.

## Genuine gaps / rough edges

- **Face recognition needs a model you supply.** No `mobilefacenet.tflite` ships
  in the repo (size + licensing). Without it at `assets/models/mobilefacenet.tflite`,
  face detection and recognition are simply off; everything else works.
- **No at-rest encryption.** Files are protected only by the OS app sandbox. A
  thief with your *unlocked* phone, a forensic image, or a backup ZIP you shared
  can read the footage. Encrypted-at-rest storage is a named horizon, not a
  feature.
- **Backups are plaintext ZIPs.** Portable and inspectable — and therefore
  unencrypted. Treat an exported backup like the private footage it is.
- **The web PWA is a reduced app.** On web there is **no face recognition, no push
  notifications, and no home-screen widget** (platform stubs). Video runs via
  `ffmpeg.wasm`, which is slower than the native binary and requires cross-origin
  isolation to be served correctly (see
  [how-to/ship-web-pwa.md](how-to/ship-web-pwa.md)).
- **iOS is PWA-only.** There is no native iOS app; iPhone users install via Safari
  "Add to Home Screen."
- **Compilation is straight normalized concat.** Clips are conformed to a uniform
  format and joined, with an optional burned-in overlay and audio mix — there are
  **no real transitions** and no smart/auto editing.
- **Persistence is a single JSON file rewritten on every change.** Fine for a
  personal diary; it is not a database and won't scale to very large datasets, and
  it has no indexed queries ([ADR-0003](adr/0003-json-metadata-no-db.md)).
- **Recognition is best-effort.** MobileFaceNet + a 0.6 cosine threshold will miss
  and occasionally mismatch faces, especially children as they change. It's a
  convenience for tagging, not an identity system.
- **FFmpeg makes for a large binary.** Always build split-per-ABI APKs; a fat APK
  is very large (see the README).

## Not planned

- A recommendation feed, social graph, or "memories" push from a server — none of
  the mechanics for these exist, and they conflict with the invariants above.
