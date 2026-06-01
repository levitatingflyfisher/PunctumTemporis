// Platform twin: native media picker (photo_manager) on Android,
// stub on web (web gallery import uses file_picker in GalleryImportScreen directly).
export 'media_picker_screen_native.dart'
    if (dart.library.js_interop) 'media_picker_screen_web.dart';
