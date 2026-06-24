// Platform twin: exports the native FaceService on Android,
// and a no-op stub on web (ML Kit + TFLite not available on web).
export 'face_service_impl.dart'
    if (dart.library.js_interop) 'face_service_stub.dart';
