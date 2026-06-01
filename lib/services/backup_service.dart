import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../platform/file_storage.dart';
import 'storage_service.dart';

class BackupInfo {
  final int clipCount;
  final String? dateRange; // "2025-01-01 to 2026-02-12"
  final int sizeBytes;
  final int compilationCount;
  final int faceCount;

  BackupInfo({
    required this.clipCount,
    this.dateRange,
    required this.sizeBytes,
    this.compilationCount = 0,
    this.faceCount = 0,
  });
}

class BackupService {
  final StorageService storageService;

  BackupService(this.storageService);

  /// Estimate backup size in bytes (clips + thumbnails + faces + metadata)
  Future<int> getBackupSize() async {
    int totalSize = 0;

    // Clips and thumbnails
    for (final clipList in storageService.clips.values) {
      for (final clip in clipList) {
        final clipBytes = await FileStorage.readBytes(clip.filePath);
        if (clipBytes != null) totalSize += clipBytes.length;
        if (clip.thumbnailPath != null) {
          final thumbBytes = await FileStorage.readBytes(clip.thumbnailPath!);
          if (thumbBytes != null) totalSize += thumbBytes.length;
        }
      }
    }

    // Face images — derive paths from known people names
    // (knownPeople is empty on web since face recognition is disabled)
    final appDir = await FileStorage.appDocDir();
    final facesDir = '$appDir/faces';
    for (final name in storageService.knownPeople.keys) {
      final facePath = '$facesDir/$name.jpg';
      final faceBytes = await FileStorage.readBytes(facePath);
      if (faceBytes != null) totalSize += faceBytes.length;
    }

    // Metadata overhead estimate
    totalSize += 10000;

    return totalSize;
  }

  /// Create a backup ZIP. On native, writes to [outputPath]. On web, triggers browser download.
  Future<void> createBackup(
    String outputPath,
    void Function(double progress) onProgress,
  ) async {
    final archive = Archive();
    final appDir = await FileStorage.appDocDir();
    final metadataPath = '$appDir/metadata.json';
    final facesDir = '$appDir/faces';

    // Collect all files to include as (archiveName, bytes) pairs
    final filesToAdd = <(String, Uint8List)>[];

    // Metadata
    final metadataBytes = await FileStorage.readBytes(metadataPath);
    if (metadataBytes != null) {
      filesToAdd.add(('metadata.json', metadataBytes));
    }

    // Clips and thumbnails
    for (final clipList in storageService.clips.values) {
      for (final clip in clipList) {
        final clipBytes = await FileStorage.readBytes(clip.filePath);
        if (clipBytes != null) {
          final fileName = clip.filePath.split('/').last;
          filesToAdd.add(('clips/$fileName', clipBytes));
        }
        if (clip.thumbnailPath != null) {
          final thumbBytes = await FileStorage.readBytes(clip.thumbnailPath!);
          if (thumbBytes != null) {
            final fileName = clip.thumbnailPath!.split('/').last;
            filesToAdd.add(('thumbnails/$fileName', thumbBytes));
          }
        }
      }
    }

    // Face images (empty on web — knownPeople is always empty when face recognition is disabled)
    for (final name in storageService.knownPeople.keys) {
      final facePath = '$facesDir/$name.jpg';
      final faceBytes = await FileStorage.readBytes(facePath);
      if (faceBytes != null) {
        filesToAdd.add(('faces/$name.jpg', faceBytes));
      }
    }

    // Add files to archive with progress
    for (var i = 0; i < filesToAdd.length; i++) {
      final (name, bytes) = filesToAdd[i];
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      onProgress((i + 1) / filesToAdd.length * 0.8);
    }

    // Encode to ZIP
    onProgress(0.85);
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('Failed to encode backup ZIP');
    }

    // Write or download
    onProgress(0.9);
    final zipBytes = Uint8List.fromList(zipData);
    if (kIsWeb) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      await FileStorage.downloadFile(
          zipBytes, 'onesecond_backup_$ts.zip', 'application/zip');
    } else {
      await FileStorage.writeBytes(outputPath, zipBytes);
    }
    onProgress(1.0);
  }

  /// Validate a backup ZIP from raw bytes and return info about its contents.
  Future<BackupInfo> validateBackup(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    int clipCount = 0;
    int faceCount = 0;
    int compilationCount = 0;
    String? dateRange;

    for (final entry in archive) {
      if (entry.name.startsWith('clips/') && entry.name.endsWith('.mp4')) {
        clipCount++;
      }
      if (entry.name.startsWith('faces/')) {
        faceCount++;
      }
    }

    // Try to read metadata for date range
    final metadataEntry = archive.findFile('metadata.json');
    if (metadataEntry != null) {
      try {
        final content = utf8.decode(metadataEntry.content as List<int>);
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data['clips'] != null) {
          final clipsData = data['clips'] as Map<String, dynamic>;
          final dates = clipsData.keys.toList()..sort();
          if (dates.isNotEmpty) {
            dateRange = '${dates.first} to ${dates.last}';
          }
          // Count actual clips from metadata (more accurate than file count)
          clipCount = 0;
          for (final value in clipsData.values) {
            if (value is List) {
              clipCount += value.length;
            } else if (value is Map) {
              clipCount += 1;
            }
          }
        }
        compilationCount = (data['compilations'] as List?)?.length ?? 0;
      } catch (_) {}
    }

    return BackupInfo(
      clipCount: clipCount,
      dateRange: dateRange,
      sizeBytes: bytes.length,
      faceCount: faceCount,
      compilationCount: compilationCount,
    );
  }

  /// Restore a backup ZIP from raw bytes, merging or replacing existing data.
  Future<void> restoreBackup(
    Uint8List bytes,
    void Function(double progress) onProgress, {
    bool replace = false,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    final appDir = await FileStorage.appDocDir();
    final clipsDir = '$appDir/clips';
    final thumbnailsDir = '$appDir/thumbnails';
    final facesDir = '$appDir/faces';
    final metadataPath = '$appDir/metadata.json';

    await FileStorage.ensureDir(clipsDir);
    await FileStorage.ensureDir(thumbnailsDir);
    await FileStorage.ensureDir(facesDir);

    final totalEntries = archive.length;

    // Extract files
    for (var i = 0; i < archive.length; i++) {
      final entry = archive[i];
      if (entry.isFile) {
        // Reject path traversal (ZIP Slip)
        if (!_isSafeEntryName(entry.name)) {
          onProgress((i + 1) / totalEntries * 0.8);
          continue;
        }
        String? destPath;

        if (entry.name == 'metadata.json') {
          // Handled below
        } else if (entry.name.startsWith('clips/')) {
          destPath = '$clipsDir/${entry.name.substring(6)}';
        } else if (entry.name.startsWith('thumbnails/')) {
          destPath = '$thumbnailsDir/${entry.name.substring(11)}';
        } else if (entry.name.startsWith('faces/')) {
          destPath = '$facesDir/${entry.name.substring(6)}';
        }

        if (destPath != null) {
          if (replace || !await FileStorage.exists(destPath)) {
            await FileStorage.writeBytes(
                destPath, Uint8List.fromList(entry.content as List<int>));
          }
        }
      }
      onProgress((i + 1) / totalEntries * 0.8);
    }

    // Restore metadata
    onProgress(0.85);
    final metadataEntry = archive.findFile('metadata.json');
    if (metadataEntry != null) {
      final content = utf8.decode(metadataEntry.content as List<int>);
      final backupData = jsonDecode(content) as Map<String, dynamic>;

      if (replace) {
        await FileStorage.writeString(metadataPath, content);
      } else {
        await _mergeMetadata(backupData, metadataPath);
      }
    }

    onProgress(0.95);

    // Reload storage service
    await storageService.initialize();
    onProgress(1.0);
  }

  /// Returns true if the ZIP entry name is free of path traversal sequences.
  static bool _isSafeEntryName(String name) {
    final parts = name.split('/');
    return !parts.any((p) => p == '..' || p == '.' || p.isEmpty && parts.length > 1);
  }

  Future<void> _mergeMetadata(
      Map<String, dynamic> backupData, String metadataPath) async {
    Map<String, dynamic> existingData = {};

    final content = await FileStorage.readString(metadataPath);
    if (content != null) {
      try {
        existingData = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Merge clips
    final existingClips =
        existingData['clips'] as Map<String, dynamic>? ?? {};
    final backupClips = backupData['clips'] as Map<String, dynamic>? ?? {};

    for (final entry in backupClips.entries) {
      if (!existingClips.containsKey(entry.key)) {
        existingClips[entry.key] = entry.value;
      } else {
        // Merge clip lists — add any clips with IDs not already present
        final existingList = existingClips[entry.key];
        final backupList = entry.value;
        if (existingList is List && backupList is List) {
          final existingIds = existingList
              .whereType<Map<String, dynamic>>()
              .map((c) => c['id'] as String?)
              .toSet();
          for (final backupClip in backupList) {
            if (backupClip is Map<String, dynamic>) {
              if (!existingIds.contains(backupClip['id'])) {
                existingList.add(backupClip);
              }
            }
          }
        }
      }
    }

    existingData['clips'] = existingClips;

    // Merge known people
    final existingPeople =
        existingData['knownPeople'] as Map<String, dynamic>? ?? {};
    final backupPeople =
        backupData['knownPeople'] as Map<String, dynamic>? ?? {};
    for (final entry in backupPeople.entries) {
      if (!existingPeople.containsKey(entry.key)) {
        existingPeople[entry.key] = entry.value;
      }
    }
    existingData['knownPeople'] = existingPeople;

    // Merge compilations — add any with IDs not already present
    final existingComps = (existingData['compilations'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final backupComps = (backupData['compilations'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final existingCompIds = existingComps.map((c) => c['id'] as String?).toSet();
    for (final comp in backupComps) {
      if (!existingCompIds.contains(comp['id'])) {
        existingComps.add(comp);
      }
    }
    existingData['compilations'] = existingComps;

    await FileStorage.writeString(metadataPath, jsonEncode(existingData));
  }
}
