# ADR-0002: One codebase, native + web, via compile-time platform twins

- **Status:** Accepted
- **Date:** documenting a decision load-bearing since the web/PWA release

## Context

We want the app on iPhones without an App Store (Apple's review, fees, and gate
conflict with a free, private, hobbyist-scale tool) and on the web generally. The
obvious path is a web build — but the app leans on native-only plugins:
`FFmpegKit` (a native binary), the `dart:io` filesystem, ML Kit face detection,
and local notifications. None of those exist in a browser.

The options were: fork a second web app (duplication, drift), litter services
with `if (kIsWeb)` branches (unreadable, easy to leak a native import into the web
build and break the compile), or isolate the platform boundary.

## Decision

Use a **platform-twin pattern**: for each platform-specific capability, one
public Dart file re-exports a native *or* a web implementation, chosen at compile
time by Dart conditional exports.

```dart
// lib/platform/file_storage.dart
export 'file_storage_native.dart'
    if (dart.library.js_interop) 'file_storage_web.dart';
```

Twins exist for:

- **`file_storage`** — `dart:io` on native, the Origin Private File System (OPFS)
  on web.
- **`ffmpeg_runner`** — `FFmpegKit` on native, `ffmpeg.wasm` on web.
- **`face_service`** — ML Kit + TFLite on native, a **stub** on web (recognition
  off).
- **`notification_service`** — `flutter_local_notifications` on native, a **stub**
  on web.

Service and UI code imports the public name only; it never sees which twin it
got, and never branches on `kIsWeb` for these concerns. Web-only gaps (face
recognition, push notifications, home-screen widget) are handled by the stub
returning empty/no-op results, so callers keep working unchanged.

## Consequences

- **Buys:** a single feature-complete codebase that builds to an Android APK and
  an installable PWA. A native-only import can never be dragged into the web build
  (it lives behind the twin), so the web build stays compilable. Adding a platform
  is adding a twin file.
- **Costs:** every platform capability needs *two* implementations kept in step,
  plus a matching public interface; a new native plugin is not "done" until its
  web twin (or an honest stub) exists. Web is a genuinely reduced app.
- **Forecloses:** sprinkling runtime platform checks through business logic. The
  platform boundary is a directory (`lib/platform/`), not a scattered condition.

## Alternatives considered

- **A separate web project:** rejected — guarantees drift between the two apps.
- **`kIsWeb` branches inside services:** rejected — a native-only import in a file
  that the web build also compiles breaks the whole web build, and the logic
  becomes unreadable.
