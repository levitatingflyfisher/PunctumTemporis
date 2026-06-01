import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/clip.dart';
import '../platform/file_storage.dart';
import '../services/ffmpeg_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/crt_effects.dart';
import '../widgets/thumbnail_image.dart';

bool _isVideoExt(String? ext) {
  const videoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'mts', 'm4v', 'ts', 'wmv'};
  return videoExts.contains(ext?.toLowerCase());
}

/// Web implementation of GalleryImportScreen.
/// Uses file_picker for multi-select media import (images + videos).
class GalleryImportScreen extends StatefulWidget {
  final StorageService storageService;
  final String date;

  const GalleryImportScreen({
    super.key,
    required this.storageService,
    required this.date,
  });

  @override
  State<GalleryImportScreen> createState() => _GalleryImportScreenState();
}

class _GalleryImportScreenState extends State<GalleryImportScreen> {
  final _ffmpegService = FFmpegService();

  // Single selected file for trim/preview
  String? _selectedOpfsPath;
  Uint8List? _selectedBytes;
  bool _isVideo = false;
  bool _isProcessing = false;
  String _processingLabel = '';
  int _processingIndex = 0;
  int _processingTotal = 0;

  double _trimStart = 0;
  double _selectedDuration = 1.0;
  double? _videoDuration;
  VideoPlayerController? _videoController;
  String? _videoBlobUrl;
  bool _isSeeking = false;

  // Imported clips shown at the end
  final List<Clip> _importedClips = [];

  @override
  void dispose() {
    _videoController?.dispose();
    if (_videoBlobUrl != null) FileStorage.revokeObjectUrl(_videoBlobUrl!);
    if (_selectedOpfsPath != null) {
      FileStorage.deleteFile(_selectedOpfsPath!).catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media, // accepts both images and videos
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    if (result.files.length == 1) {
      await _loadSingleFile(result.files.first);
    } else {
      await _batchImport(result.files);
    }
  }

  Future<void> _loadSingleFile(PlatformFile pf) async {
    final bytes = pf.bytes;
    if (bytes == null) return;

    setState(() => _isProcessing = true);

    // Clean up previous state
    _videoController?.dispose();
    _videoController = null;
    if (_videoBlobUrl != null) {
      FileStorage.revokeObjectUrl(_videoBlobUrl!);
      _videoBlobUrl = null;
    }
    if (_selectedOpfsPath != null) {
      await FileStorage.deleteFile(_selectedOpfsPath!).catchError((_) {});
      _selectedOpfsPath = null;
    }

    final ext = pf.extension?.toLowerCase() ?? 'mp4';
    final tempPath =
        'opfs://import_preview_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await FileStorage.writeBytes(tempPath, bytes);

    if (_isVideoExt(ext)) {
      double? duration;
      String? blobUrl;
      VideoPlayerController? controller;
      try {
        duration = await _ffmpegService.getVideoDuration(tempPath);
        final mime = ext == 'mov' ? 'video/quicktime' : 'video/$ext';
        blobUrl = FileStorage.createObjectUrl(bytes, mime);
        if (blobUrl != null) {
          controller = VideoPlayerController.networkUrl(Uri.parse(blobUrl));
          await controller.initialize();
        }
      } catch (_) {
        controller?.dispose();
        blobUrl = null;
        controller = null;
      } finally {
        if (mounted) {
          setState(() {
            _selectedOpfsPath = tempPath;
            _selectedBytes = bytes;
            _isVideo = true;
            _videoDuration = duration;
            _trimStart = 0;
            _selectedDuration = 1.0;
            _videoController = controller;
            _videoBlobUrl = blobUrl;
            _isProcessing = false;
          });
        }
      }
    } else {
      // Image — no video player needed
      if (mounted) {
        setState(() {
          _selectedOpfsPath = tempPath;
          _selectedBytes = bytes;
          _isVideo = false;
          _videoDuration = null;
          _trimStart = 0;
          _selectedDuration = 1.0;
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _batchImport(List<PlatformFile> files) async {
    setState(() {
      _isProcessing = true;
      _processingIndex = 0;
      _processingTotal = files.length;
    });

    for (var i = 0; i < files.length; i++) {
      final pf = files[i];
      final bytes = pf.bytes;
      if (bytes == null) continue;

      setState(() {
        _processingIndex = i + 1;
        _processingLabel = pf.name;
      });

      final ext = pf.extension?.toLowerCase() ?? 'mp4';
      await _importBytes(
        bytes,
        extension: ext,
        isVideo: _isVideoExt(ext),
        duration: 1.0,
        trimStart: 0.0,
      );
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _saveSelectedClip() async {
    if (_selectedOpfsPath == null || _selectedBytes == null) return;
    setState(() => _isProcessing = true);

    final ext = _selectedOpfsPath!.split('.').last;
    await _importBytes(
      _selectedBytes!,
      extension: ext,
      isVideo: _isVideo,
      duration: _selectedDuration,
      trimStart: _trimStart,
    );

    // Clean up preview
    await FileStorage.deleteFile(_selectedOpfsPath!).catchError((_) {});
    _videoController?.dispose();
    if (_videoBlobUrl != null) FileStorage.revokeObjectUrl(_videoBlobUrl!);

    if (mounted) {
      setState(() {
        _selectedOpfsPath = null;
        _selectedBytes = null;
        _videoController = null;
        _videoBlobUrl = null;
        _videoDuration = null;
        _isProcessing = false;
      });
    }
  }

  Future<void> _importBytes(
    Uint8List bytes, {
    required String extension,
    required bool isVideo,
    required double duration,
    required double trimStart,
  }) async {
    final clipId = widget.storageService.generateId();
    final outputPath = widget.storageService.getClipPath(clipId);
    final thumbnailPath = widget.storageService.getThumbnailPath(clipId);

    final tempPath = 'opfs://import_tmp_$clipId.$extension';
    await FileStorage.writeBytes(tempPath, bytes);

    String? result;
    if (isVideo) {
      result = await _ffmpegService.extractSegment(
        tempPath,
        outputPath,
        trimStart,
        duration: duration,
      );
    } else {
      // Image → convert to 1s video via ffmpeg
      result = await _ffmpegService.photoToVideo(tempPath, outputPath);
    }

    await FileStorage.deleteFile(tempPath).catchError((_) {});

    if (result == null) {
      _showError('Failed to process file');
      return;
    }

    await _ffmpegService.generateThumbnail(outputPath, thumbnailPath);

    final clip = Clip(
      id: clipId,
      date: widget.date,
      filePath: outputPath,
      thumbnailPath: thumbnailPath,
      type: ClipType.video,
      createdAt: DateTime.now(),
      capturedAt: DateTime.now(),
      duration: isVideo ? duration : 1.0,
    );

    await widget.storageService.addClip(clip);
    if (mounted) setState(() => _importedClips.add(clip));
  }

  Future<void> _seekTo(double seconds) async {
    if (_videoController == null || _isSeeking) return;
    _isSeeking = true;
    try {
      await _videoController!.pause();
      await _videoController!
          .seekTo(Duration(milliseconds: (seconds * 1000).toInt()));
      await Future.delayed(const Duration(milliseconds: 50));
    } finally {
      _isSeeking = false;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Operation in progress — please wait')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          'IMPORT MEDIA',
          style: AppTheme.pixelFont(fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_importedClips.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'DONE (${_importedClips.length})',
                style: AppTheme.monoFont(
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DATE: ${widget.date}',
                      style: AppTheme.monoFont(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick video or image files to import as clips.',
                      style: AppTheme.monoFont(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Pick button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RetroButton(
                  onPressed: _isProcessing ? null : _pickFiles,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.perm_media, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'PICK FILE(S)',
                        style: AppTheme.monoFont(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_selectedOpfsPath != null && !_isProcessing)
                Expanded(child: _buildTrimUI(theme))
              else if (_importedClips.isNotEmpty && _selectedOpfsPath == null)
                Expanded(child: _buildImportedList(theme))
              else
                Expanded(child: _buildEmptyHint(theme)),
            ],
          ),

          // Processing overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _processingTotal > 1
                            ? 'IMPORTING $_processingIndex / $_processingTotal\n$_processingLabel'
                            : 'PROCESSING...',
                        textAlign: TextAlign.center,
                        style: AppTheme.monoFont(
                            fontSize: 13, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildEmptyHint(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.perm_media,
              size: 64, color: theme.colorScheme.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'NO FILE SELECTED',
            style: AppTheme.pixelFont(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'VIDEOS + IMAGES SUPPORTED',
            style: AppTheme.monoFont(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimUI(ThemeData theme) {
    final hasLongVideo =
        _isVideo && _videoDuration != null && _videoDuration! > 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Preview
          if (!_isVideo && _selectedBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: Image.memory(_selectedBytes!, fit: BoxFit.contain),
              ),
            )
          else if (_isVideo &&
              _videoController != null &&
              _videoController!.value.isInitialized)
            GestureDetector(
              onTap: () {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
                setState(() {});
              },
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            Container(
              height: 180,
              color: Colors.black,
              child: Center(
                child: Icon(
                  _isVideo ? Icons.videocam : Icons.image,
                  size: 64,
                  color: theme.colorScheme.primary.withOpacity(0.4),
                ),
              ),
            ),

          const SizedBox(height: 16),

          if (!_isVideo)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'IMAGE → 1s VIDEO CLIP',
                style: AppTheme.monoFont(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

          if (hasLongVideo) ...[
            Text(
              'SELECT ${_selectedDuration.toStringAsFixed(1)}s SEGMENT',
              style: AppTheme.pixelFont(
                fontSize: 11,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1.0, 2.0, 3.0, 5.0]
                  .where((d) => d <= _videoDuration!)
                  .map((d) {
                final isSelected = _selectedDuration == d;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedDuration = d;
                      final maxStart = _videoDuration! - d;
                      if (_trimStart > maxStart) {
                        _trimStart = maxStart.clamp(0, double.infinity);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                            color: theme.colorScheme.primary, width: 2),
                      ),
                      child: Text(
                        '${d.toInt()}s',
                        style: AppTheme.monoFont(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_formatTime(_trimStart),
                    style: AppTheme.monoFont(
                        fontSize: 11, color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: _trimStart,
                    min: 0,
                    max: (_videoDuration! - _selectedDuration)
                        .clamp(0, double.infinity),
                    onChanged: (v) => setState(() => _trimStart = v),
                    onChangeEnd: (v) => _seekTo(v),
                    activeColor: theme.colorScheme.primary,
                  ),
                ),
                Text(_formatTime(_trimStart + _selectedDuration),
                    style: AppTheme.monoFont(
                        fontSize: 11, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RetroButton(
                onPressed: () async {
                  _videoController?.dispose();
                  if (_videoBlobUrl != null) {
                    FileStorage.revokeObjectUrl(_videoBlobUrl!);
                  }
                  await FileStorage.deleteFile(_selectedOpfsPath!)
                      .catchError((_) {});
                  setState(() {
                    _selectedOpfsPath = null;
                    _selectedBytes = null;
                    _videoController = null;
                    _videoBlobUrl = null;
                    _videoDuration = null;
                  });
                },
                color: Colors.grey[800],
                child: Text('CANCEL',
                    style: AppTheme.monoFont(
                        fontSize: 12, color: Colors.white)),
              ),
              RetroButton(
                onPressed: _saveSelectedClip,
                child: Text('IMPORT',
                    style: AppTheme.monoFont(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImportedList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${_importedClips.length} CLIP(S) IMPORTED',
            style: AppTheme.pixelFont(
              fontSize: 13,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _importedClips.length,
            itemBuilder: (ctx, i) {
              final clip = _importedClips[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RetroCard(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.primary, width: 1),
                        ),
                        child: clip.thumbnailPath != null
                            ? ThumbnailImage(path: clip.thumbnailPath!)
                            : Icon(Icons.videocam,
                                color: theme.colorScheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clip.date,
                              style: AppTheme.monoFont(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${clip.duration?.toStringAsFixed(1) ?? "1.0"}s',
                              style: AppTheme.monoFont(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle,
                          color: theme.colorScheme.primary, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: RetroButton(
                  onPressed: _pickFiles,
                  color: Colors.grey[800],
                  child: Text(
                    'ADD MORE',
                    style: AppTheme.monoFont(
                        fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RetroButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'DONE',
                    style: AppTheme.monoFont(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(double seconds) {
    final secs = seconds.floor();
    final ms = ((seconds - secs) * 10).floor();
    return '$secs.${ms}s';
  }
}
