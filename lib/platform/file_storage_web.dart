import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

// ── JS interop types for the Origin Private File System (OPFS) API ────────────

@JS('navigator.storage')
external _StorageManager get _storageManager;

extension type _StorageManager._(JSObject _) implements JSObject {
  external JSPromise<_FileSystemDirectoryHandle> getDirectory();
}

extension type _GetHandleOptions._(JSObject _) implements JSObject {
  external factory _GetHandleOptions({bool create});
}

extension type _RemoveEntryOptions._(JSObject _) implements JSObject {
  external factory _RemoveEntryOptions({bool recursive});
}

extension type _FileSystemDirectoryHandle._(JSObject _) implements JSObject {
  external JSPromise<_FileSystemDirectoryHandle> getDirectoryHandle(
      String name, _GetHandleOptions options);
  external JSPromise<_FileSystemFileHandle> getFileHandle(
      String name, _GetHandleOptions options);
  external JSPromise<JSAny?> removeEntry(
      String name, _RemoveEntryOptions options);
}

extension type _FileSystemFileHandle._(JSObject _) implements JSObject {
  external JSPromise<_FileSystemWritableFileStream> createWritable();
  external JSPromise<_WebFile> getFile();
}

extension type _FileSystemWritableFileStream._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> write(JSAny data);
  external JSPromise<JSAny?> close();
}

extension type _WebFile._(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

@JS('URL.createObjectURL')
external String _createObjectURL(JSObject blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectURL(String url);

extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny?> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

// ── Path helpers ──────────────────────────────────────────────────────────────

const _opfsScheme = 'opfs://';

/// Strips the opfs:// sentinel and returns [dirParts, filename].
/// e.g. 'opfs://clips/abc.mp4' → (['clips'], 'abc.mp4')
(List<String>, String) _parsePath(String path) {
  final relative = path.startsWith(_opfsScheme)
      ? path.substring(_opfsScheme.length)
      : path;
  final parts = relative.split('/');
  final filename = parts.last;
  final dirs = parts.length > 1 ? parts.sublist(0, parts.length - 1) : <String>[];
  return (dirs, filename);
}

Future<_FileSystemDirectoryHandle> _getRoot() async {
  return (await _storageManager.getDirectory().toDart);
}

/// Navigates to the parent directory handle, creating directories as needed.
Future<_FileSystemDirectoryHandle> _getParentDir(
    _FileSystemDirectoryHandle root, List<String> dirs,
    {bool create = true}) async {
  var current = root;
  for (final dir in dirs) {
    if (dir.isEmpty) continue;
    current = await current
        .getDirectoryHandle(dir, _GetHandleOptions(create: create))
        .toDart;
  }
  return current;
}

// ── FileStorage public API (mirrors file_storage_native.dart) ─────────────────

class FileStorage {
  // ── Directories ─────────────────────────────────────────────────────────────

  static Future<String> appDocDir() async => _opfsScheme;

  /// Web has no external storage concept; returns null.
  static Future<String?> externalStorageDir() async => null;

  /// On web, OPFS directories are created on demand during writes.
  static Future<void> ensureDir(String path) async {}

  // ── Existence ────────────────────────────────────────────────────────────────

  static Future<bool> exists(String path) async {
    try {
      final (dirs, filename) = _parsePath(path);
      final root = await _getRoot();
      final parent = await _getParentDir(root, dirs, create: false);
      await parent.getFileHandle(filename, _GetHandleOptions(create: false)).toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Directory existence — always returns false on web (migration is Android-only).
  static Future<bool> dirExists(String path) async => false;

  /// Sync existence check — always returns false on web (OPFS is async only).
  /// Callers that use existsSync should be updated to use async exists().
  static bool existsSync(String path) => false;

  // ── Read ─────────────────────────────────────────────────────────────────────

  static Future<Uint8List?> readBytes(String path) async {
    try {
      final (dirs, filename) = _parsePath(path);
      final root = await _getRoot();
      final parent = await _getParentDir(root, dirs, create: false);
      final fileHandle = await parent
          .getFileHandle(filename, _GetHandleOptions(create: false))
          .toDart;
      final webFile = await fileHandle.getFile().toDart;
      final buffer = await webFile.arrayBuffer().toDart;
      return buffer.toDart.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readString(String path) async {
    final bytes = await readBytes(path);
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  // ── Write ────────────────────────────────────────────────────────────────────

  static Future<void> writeBytes(String path, Uint8List bytes) async {
    final (dirs, filename) = _parsePath(path);
    final root = await _getRoot();
    final parent = await _getParentDir(root, dirs, create: true);
    final fileHandle =
        await parent.getFileHandle(filename, _GetHandleOptions(create: true)).toDart;
    final writable = await fileHandle.createWritable().toDart;
    await writable.write(bytes.toJS).toDart;
    await writable.close().toDart;
  }

  static Future<void> writeString(String path, String content) async {
    await writeBytes(path, Uint8List.fromList(utf8.encode(content)));
  }

  // ── Delete / Copy ─────────────────────────────────────────────────────────────

  static Future<void> deleteFile(String path) async {
    try {
      final (dirs, filename) = _parsePath(path);
      final root = await _getRoot();
      final parent = await _getParentDir(root, dirs, create: false);
      await parent
          .removeEntry(filename, _RemoveEntryOptions(recursive: false))
          .toDart;
    } catch (_) {}
  }

  static Future<void> copyFile(String sourcePath, String destPath) async {
    final bytes = await readBytes(sourcePath);
    if (bytes != null) await writeBytes(destPath, bytes);
  }

  // ── Web-only helpers ──────────────────────────────────────────────────────────

  /// Triggers a browser download of [bytes] as a file named [filename].
  static Future<void> downloadFile(
      Uint8List bytes, String filename, String mimeType) async {
    final blob = _Blob(
      [bytes.toJS].toJS,
      _BlobOptions(type: mimeType),
    );
    final url = _createObjectURL(blob);
    // Create a temporary <a> element, click it, then clean up.
    final anchor = _createDownloadAnchor(url, filename);
    _clickElement(anchor);
    // Revoke after a short delay to allow download to start
    Future.delayed(const Duration(seconds: 2), () => _revokeObjectURL(url));
  }

  /// Creates an in-memory blob URL for [bytes] (used for video playback).
  static String? createObjectUrl(Uint8List bytes, String mimeType) {
    final blob = _Blob(
      [bytes.toJS].toJS,
      _BlobOptions(type: mimeType),
    );
    return _createObjectURL(blob);
  }

  /// Revokes a blob URL created by [createObjectUrl].
  static void revokeObjectUrl(String url) {
    _revokeObjectURL(url);
  }
}

// ── DOM helpers for download trigger ──────────────────────────────────────────

@JS('document.createElement')
external JSObject _domCreateElement(String tag);

@JS()
extension type _AnchorElement._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

JSObject _createDownloadAnchor(String url, String filename) {
  final a = _domCreateElement('a') as _AnchorElement;
  a.href = url;
  a.download = filename;
  return a as JSObject;
}

void _clickElement(JSObject element) {
  (element as _AnchorElement).click();
}
