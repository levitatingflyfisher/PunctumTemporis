// Where the web build's ffmpeg.wasm lives. Pure Dart, so the VM tests can
// check it; ffmpeg_runner_web.dart (js_interop) is the only caller.

/// The vendored ffmpeg.wasm core, under `web/`.
const ffmpegCoreJs = 'ffmpeg/ffmpeg-core.js';
const ffmpegCoreWasm = 'ffmpeg/ffmpeg-core.wasm';

/// Every file the web runner causes the browser to fetch for ffmpeg.
/// `ffmpeg.js` is loaded by index.html; it starts `814.ffmpeg.js` as its
/// worker from its own directory.
const ffmpegWebAssets = [
  'ffmpeg/ffmpeg.js',
  'ffmpeg/814.ffmpeg.js',
  ffmpegCoreJs,
  ffmpegCoreWasm,
];

/// [asset] as an absolute URL on the page's own origin.
///
/// ffmpeg.wasm hands coreURL/wasmURL to its worker, which resolves a
/// relative path against the WORKER's URL (`…/ffmpeg/814.ffmpeg.js`), not
/// the page's — `ffmpeg/ffmpeg-core.js` became `…/ffmpeg/ffmpeg/…` and
/// 404'd. Resolving against `document.baseURI` (the `<base href>`) first
/// gives the worker a URL it cannot misread, whatever route is showing.
String ffmpegAssetUrl(String baseUri, String asset) =>
    Uri.parse(baseUri).resolve(asset).toString();
