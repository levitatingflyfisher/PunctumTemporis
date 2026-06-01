import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/ffmpeg_service.dart';
import '../models/clip.dart';
import '../widgets/crt_effects.dart';
import 'media_picker_screen.dart';
import 'clip_preview_screen.dart';
import '../utils/location_util.dart';
import '../services/face_service.dart';

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

  File? _selectedFile;
  bool _isVideo = false;
  bool _isProcessing = false;
  double _trimStart = 0;
  double _selectedDuration = 1.0;
  double? _videoDuration;
  VideoPlayerController? _videoController;
  bool _isSeeking = false;
  String? _exifDate;
  double? _latitude;
  double? _longitude;
  String? _locationLabel;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _openMediaPicker() async {
    final asset = await Navigator.push<AssetEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPickerScreen(
          targetDate: widget.date,
          crtEnabled: widget.storageService.getCrtEffects(),
        ),
      ),
    );

    if (asset == null) return;

    final file = await asset.file;
    if (file == null) {
      _showError('Could not access selected file');
      return;
    }

    final creationDate = asset.createDateTime;
    final exifDateStr =
        '${creationDate.year}-${creationDate.month.toString().padLeft(2, '0')}-${creationDate.day.toString().padLeft(2, '0')}';

    // Extract GPS from asset
    final latLng = await asset.latlngAsync();
    double? lat;
    double? lng;
    String? locLabel;
    if (latLng != null && latLng.latitude != 0 && latLng.longitude != 0) {
      lat = latLng.latitude;
      lng = latLng.longitude;
      locLabel = await LocationUtil.reverseGeocodeLabel(lat, lng);
    }

    setState(() {
      _exifDate = exifDateStr;
      _latitude = lat;
      _longitude = lng;
      _locationLabel = locLabel;
    });

    if (exifDateStr != widget.date) {
      if (mounted) {
        final exifLabel = DateFormat('MMM d, yyyy').format(creationDate);
        final targetLabel =
            DateFormat('MMM d, yyyy').format(DateTime.parse(widget.date));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Media date ($exifLabel) differs from target ($targetLabel)'),
            backgroundColor: Colors.amber[800],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    if (asset.type == AssetType.video) {
      setState(() {
        _selectedFile = file;
        _isVideo = true;
        _isProcessing = true;
      });

      final duration = await _ffmpegService.getVideoDuration(file.path);

      _videoController?.dispose();
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      await _videoController!.setLooping(false);

      setState(() {
        _videoDuration =
            duration ?? _videoController?.value.duration.inSeconds.toDouble();
        _trimStart = 0;
        _selectedDuration = 1.0;
        _isProcessing = false;
      });
    } else {
      setState(() {
        _selectedFile = file;
        _isVideo = false;
      });
    }
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

  void _playPreview() async {
    if (_videoController == null) return;

    await _seekTo(_trimStart);
    await _videoController!.play();

    Future.delayed(Duration(milliseconds: (_selectedDuration * 1000).toInt()),
        () {
      if (mounted &&
          _videoController != null &&
          _videoController!.value.isPlaying) {
        _videoController!.pause();
      }
    });
  }

  Future<void> _import() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final clipId = widget.storageService.generateId();
      final outputPath = widget.storageService.getClipPath(clipId);
      final thumbnailPath = widget.storageService.getThumbnailPath(clipId);

      String? result;

      if (_isVideo) {
        result = await _ffmpegService.extractSegment(
          _selectedFile!.path,
          outputPath,
          _trimStart,
          duration: _selectedDuration,
        );
      } else {
        result = await _ffmpegService.photoToVideo(
          _selectedFile!.path,
          outputPath,
          duration: _selectedDuration,
        );
      }

      if (result == null) {
        _showError('Failed to process media');
        setState(() => _isProcessing = false);
        return;
      }

      await _ffmpegService.generateThumbnail(outputPath, thumbnailPath);

      // Auto-detect faces in thumbnail
      final faceService = FaceService.instance;
      final detectedFaces = <String>[];
      final autoTags = <String>[];
      if (faceService.isAvailable) {
        final faces = await faceService.detectAndEmbed(thumbnailPath);
        for (final face in faces) {
          final match = faceService.findBestMatch(
            face.embedding,
            widget.storageService.knownPeople,
          );
          if (match != null) {
            detectedFaces.add(match.name);
            autoTags.add(match.name);
            if (match.score > 0.75) {
              await widget.storageService
                  .addPersonEmbedding(match.name, face.embedding);
            }
          }
        }
      }

      if (_locationLabel != null && _locationLabel!.isNotEmpty) {
        autoTags.add(_locationLabel!);
      }

      final clip = Clip(
        id: clipId,
        date: widget.date,
        filePath: outputPath,
        thumbnailPath: thumbnailPath,
        type: ClipType.imported,
        createdAt: DateTime.now(),
        duration: _selectedDuration,
        exifDate: _exifDate,
        latitude: _latitude,
        longitude: _longitude,
        locationLabel: _locationLabel,
        detectedFaces: detectedFaces,
        tags: autoTags,
      );

      await widget.storageService.addClip(clip);

      if (mounted) {
        // Navigate to clip preview for tagging/location editing
        _videoController?.dispose();
        _videoController = null;
        setState(() {
          _selectedFile = null;
          _isVideo = false;
          _isProcessing = false;
          _trimStart = 0;
          _selectedDuration = 1.0;
          _videoDuration = null;
          _isSeeking = false;
          _exifDate = null;
          _latitude = null;
          _longitude = null;
          _locationLabel = null;
        });

        final action = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => ClipPreviewScreen(
              storageService: widget.storageService,
              clip: clip,
              showImportActions: true,
            ),
          ),
        );

        if (!mounted) return;

        if (action == 'add_more') {
          _openMediaPicker();
        } else {
          // Default: return to calendar
          Navigator.pop(context);
        }
        return;
      }
    } catch (e) {
      _showError('Import failed: $e');
    }

    setState(() => _isProcessing = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isProcessing && _selectedFile == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_isProcessing) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Operation in progress — please wait')),
            );
          } else {
            // Reset state and reopen media picker instead of exiting screen
            _videoController?.dispose();
            _videoController = null;
            setState(() {
              _selectedFile = null;
              _isVideo = false;
              _exifDate = null;
              _latitude = null;
              _longitude = null;
              _locationLabel = null;
            });
            _openMediaPicker();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IMPORT', style: AppTheme.pixelFont(fontSize: 12)),
              Text(
                widget.date,
                style: AppTheme.monoFont(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (_selectedFile != null) {
                _videoController?.dispose();
                _videoController = null;
                setState(() {
                  _selectedFile = null;
                  _isVideo = false;
                  _exifDate = null;
                  _latitude = null;
                  _longitude = null;
                  _locationLabel = null;
                });
                _openMediaPicker();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: CrtOverlay(
          enabled: widget.storageService.getCrtEffects(),
          child: _selectedFile == null
              ? _buildPicker()
              : _isVideo
                  ? _buildVideoEditor()
                  : _buildImagePreview(),
        ),
      ),
    );
  }

  Widget _buildPicker() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SELECT MEDIA FOR ${widget.date}',
            style: AppTheme.monoFont(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _openMediaPicker,
            child: RetroCard(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'BROWSE GALLERY',
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL IMPORT',
              style: AppTheme.monoFont(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Image.file(
              _selectedFile!,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'This photo will be converted to a ${_selectedDuration.toStringAsFixed(1)}s video.',
                style: AppTheme.monoFont(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildDurationSelector(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  RetroButton(
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _exifDate = null;
                        _latitude = null;
                        _longitude = null;
                        _locationLabel = null;
                      });
                      _openMediaPicker();
                    },
                    color: Colors.grey[800],
                    child: Text(
                      'CANCEL',
                      style: AppTheme.monoFont(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RetroButton(
                    onPressed: _isProcessing ? null : _import,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'IMPORT',
                            style: AppTheme.monoFont(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoEditor() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Video preview
        Expanded(
          child:
              _videoController != null && _videoController!.value.isInitialized
                  ? GestureDetector(
                      onTap: _playPreview,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                          if (!_videoController!.value.isPlaying)
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                                border: Border.all(
                                    color: theme.colorScheme.primary, width: 2),
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: theme.colorScheme.primary,
                                size: 32,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
        ),

        // Trim controls
        if (_videoDuration != null)
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'SELECT ${_selectedDuration.toStringAsFixed(1)}s SEGMENT',
                  style: AppTheme.pixelFont(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // Start time slider
                Row(
                  children: [
                    Text(
                      _formatTime(_trimStart),
                      style: AppTheme.monoFont(fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: _trimStart,
                        min: 0,
                        max: (_videoDuration! - _selectedDuration)
                            .clamp(0, double.infinity),
                        onChanged: (value) {
                          setState(() => _trimStart = value);
                        },
                        onChangeEnd: (value) {
                          _seekTo(value);
                        },
                        activeColor: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      _formatTime(_trimStart + _selectedDuration),
                      style: AppTheme.monoFont(fontSize: 12),
                    ),
                  ],
                ),

                Text(
                  'Total: ${_formatTime(_videoDuration!)}',
                  style: AppTheme.monoFont(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),

                const SizedBox(height: 16),
                _buildDurationSelector(),
              ],
            ),
          ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RetroButton(
                onPressed: () {
                  _videoController?.dispose();
                  _videoController = null;
                  setState(() {
                    _selectedFile = null;
                    _exifDate = null;
                    _latitude = null;
                    _longitude = null;
                    _locationLabel = null;
                  });
                  _openMediaPicker();
                },
                color: Colors.grey[800],
                child: Text(
                  'CANCEL',
                  style: AppTheme.monoFont(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              RetroButton(
                onPressed: _isProcessing ? null : _import,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'IMPORT',
                        style: AppTheme.monoFont(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    final theme = Theme.of(context);
    final durations = [1.0, 2.0, 3.0, 5.0];

    return Column(
      children: [
        Text(
          'DURATION',
          style: AppTheme.pixelFont(
            fontSize: 11,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: durations.map((d) {
            final isSelected = _selectedDuration == d;
            final isAvailable =
                !_isVideo || (_videoDuration != null && _videoDuration! >= d);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: isAvailable
                    ? () {
                        setState(() {
                          _selectedDuration = d;
                          if (_isVideo && _videoDuration != null) {
                            final maxStart = _videoDuration! - d;
                            if (_trimStart > maxStart) {
                              _trimStart = maxStart.clamp(0, double.infinity);
                            }
                          }
                        });
                      }
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isAvailable
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '${d.toInt()}s',
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : isAvailable
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
