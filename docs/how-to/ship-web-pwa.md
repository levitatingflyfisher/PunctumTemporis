# How-to: ship the web PWA

Task-oriented. Punctum Temporis builds to an installable Progressive Web App so
iPhone users (and anyone) can run it from a URL — no App Store. The web build is
the platform twin ([ADR-0002](../adr/0002-platform-twin.md)): OPFS for storage,
`ffmpeg.wasm` for video, and stubs for face recognition / notifications / widget.

## Build

```bash
flutter build web --release --base-href "/<path>/"
# → build/web/
```

Use `--base-href` to match where the app is served (e.g. `"/PunctumTemporis/"`
for a GitHub Pages project site, or `"/"` for a root domain).

## The one thing that will bite you: cross-origin isolation

`ffmpeg.wasm` uses `SharedArrayBuffer` for multi-threaded decoding. Browsers only
expose `SharedArrayBuffer` on a **cross-origin-isolated** page, which requires two
response headers on the document:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

On a host where you can't set headers (e.g. GitHub Pages), the app ships
**`web/coi-serviceworker.js`** (from the `coi-serviceworker` project, MIT), loaded
at the top of `web/index.html`. It installs a service worker that injects the
COOP/COEP headers client-side, enabling `SharedArrayBuffer` without server config.
If video processing on web fails with a `SharedArrayBuffer is not defined` error,
this is almost always the cause: confirm the service worker registered and the
page reports `crossOriginIsolated === true`.

The ffmpeg.wasm assets themselves are **bundled** under `web/ffmpeg/`
(`ffmpeg.js`, its worker `814.ffmpeg.js`, `ffmpeg-core.js`, `ffmpeg-core.wasm`) —
served locally, not fetched from a CDN, consistent with the local-first stance.
Two details keep it that way:

- The runner passes **absolute** core/wasm URLs, resolved against
  `document.baseURI` (`lib/platform/ffmpeg_web_assets.dart`). The worker resolves a
  relative URL against its own location, so `ffmpeg/ffmpeg-core.js` used to become
  `ffmpeg/ffmpeg/ffmpeg-core.js` and 404.
- Upstream's worker defaults `coreURL` to the unpkg CDN. The vendored copy is
  patched (see the comment at the top of `814.ffmpeg.js`) to default to the core
  beside it. If you re-vendor ffmpeg.wasm, re-apply that patch:
  `test/platform/ffmpeg_self_hosted_test.dart` fails on any third-party URL under
  `web/` that is not on its never-fetched allowlist.

## Where data lives on web

There is no `dart:io` filesystem in a browser. The web `FileStorage` twin uses the
**Origin Private File System (OPFS)** — a sandboxed, per-origin, persistent store
mirroring the native app-private layout (`clips/`, `thumbnails/`, `metadata.json`;
`faces/` is unused since recognition is off on web). Compiled montages are offered
as a **browser download** instead of being written to a `Movies/` folder.

To reduce the chance the browser evicts OPFS data under storage pressure, the app
requests **persistent storage** (`navigator.storage.persist()`) at startup.

## Deploy

Two workflows exist:

- **GitHub Pages** — `.github/workflows/deploy-web.yml` builds `flutter build web
  --release --base-href "/<repo>/"` and publishes `build/web` to the `gh-pages`
  branch (triggers on `pwa-development`, or manual dispatch).
- **Cloudflare Pages** — `.github/workflows/deploy-pwa-cloudflare.yml`.

For any host, ensure the deployed site either sets the COOP/COEP headers directly
or serves the bundled `coi-serviceworker.js` (the default).

## Web feature parity checklist

| Works on web | Disabled on web (stub) |
|---|---|
| Capture via import, calendar, compile (ffmpeg.wasm), backup/restore, year-review, themes, offline geocoding | Face recognition, push notifications, home-screen widget |
