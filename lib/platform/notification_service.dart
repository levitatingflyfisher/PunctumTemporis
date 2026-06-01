// Platform twin: exports the native NotificationService on Android,
// and a no-op stub on web (flutter_local_notifications not available on web).
export 'notification_service_impl.dart'
    if (dart.library.js_interop) 'notification_service_stub.dart';
