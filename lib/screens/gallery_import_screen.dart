// Platform twin: native gallery import (photo_manager) on Android,
// file-picker-based import on web.
export 'gallery_import_screen_native.dart'
    if (dart.library.js_interop) 'gallery_import_screen_web.dart';
