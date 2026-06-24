import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Native (Android) file storage — thin wrappers around dart:io + path_provider.
/// All paths are real filesystem paths.
class FileStorage {
  // ── Directories ────────────────────────────────────────────────────────────

  static Future<String> appDocDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static Future<String?> externalStorageDir() async {
    try {
      final dir = await getExternalStorageDirectory();
      return dir?.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> ensureDir(String path) async {
    await Directory(path).create(recursive: true);
  }

  // ── Existence ───────────────────────────────────────────────────────────────

  static Future<bool> exists(String path) async {
    return File(path).exists();
  }

  static Future<bool> dirExists(String path) async {
    return Directory(path).exists();
  }

  static bool existsSync(String path) {
    return File(path).existsSync();
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  static Future<Uint8List?> readBytes(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  static Future<String?> readString(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  static Future<void> writeBytes(String path, Uint8List bytes) async {
    await File(path).writeAsBytes(bytes);
  }

  static Future<void> writeString(String path, String content) async {
    await File(path).writeAsString(content);
  }

  // ── Delete / Copy ───────────────────────────────────────────────────────────

  static Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<void> copyFile(String sourcePath, String destPath) async {
    await File(sourcePath).copy(destPath);
  }

  // ── Web-only helpers (no-op on native) ─────────────────────────────────────

  /// Triggers a browser download of bytes. No-op on native (file is written to path instead).
  static Future<void> downloadFile(
      Uint8List bytes, String filename, String mimeType) async {
    // On native, caller should use share_plus or save to external storage directly.
    // This method is a no-op; callers check kIsWeb before calling.
  }

  /// Creates an object URL for in-memory bytes (for video playback).
  /// Returns null on native — use file:// path directly.
  static String? createObjectUrl(Uint8List bytes, String mimeType) => null;

  /// Revokes an object URL previously created by [createObjectUrl]. No-op on native.
  static void revokeObjectUrl(String url) {}
}
