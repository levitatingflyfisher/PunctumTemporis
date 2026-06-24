// Platform twin: native dart:io file system on Android,
// OPFS (Origin Private File System) async API on web.
export 'file_storage_native.dart'
    if (dart.library.js_interop) 'file_storage_web.dart';
