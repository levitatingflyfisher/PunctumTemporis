import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../models/clip.dart';
import '../platform/file_storage.dart';
import '../widgets/crt_effects.dart';
import '../widgets/thumbnail_image.dart';
import '../services/face_service.dart';
import '../services/ffmpeg_service.dart';
import 'package:share_plus/share_plus.dart';

class ClipPreviewScreen extends StatefulWidget {
  final StorageService storageService;
  final Clip clip;
  final VoidCallback? onDelete;
  final bool embedded;
  final bool showImportActions;

  const ClipPreviewScreen({
    super.key,
    required this.storageService,
    required this.clip,
    this.onDelete,
    this.embedded = false,
    this.showImportActions = false,
  });

  @override
  State<ClipPreviewScreen> createState() => _ClipPreviewScreenState();
}

class _ClipPreviewScreenState extends State<ClipPreviewScreen> {
  VideoPlayerController? _controller;
  String? _blobUrl; // web-only: blob URL for video playback, revoked on dispose
  bool _isInitialized = false;
  late Clip _clip;
  List<FaceDetectionResult> _detectedFaceResults = [];
  List<FaceDetectionResult> _unrecognizedFaces = [];
  Map<String, FaceDetectionResult> _recognizedFaceResults = {};
  Size? _thumbnailSize;

  // Trim state
  bool _isTrimming = false;
  bool _isProcessingTrim = false;
  bool _isSeeking = false;
  double _trimStart = 0;
  double _trimDuration = 1.0;
  double _videoDuration = 0;
  final _ffmpegService = FFmpegService();

  @override
  void initState() {
    super.initState();
    _clip = widget.clip;
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (!await FileStorage.exists(_clip.filePath)) {
      _showError('Video file not found');
      return;
    }

    if (kIsWeb) {
      final bytes = await FileStorage.readBytes(_clip.filePath);
      if (bytes == null) {
        _showError('Video file not found');
        return;
      }
      if (_blobUrl != null) FileStorage.revokeObjectUrl(_blobUrl!);
      _blobUrl = FileStorage.createObjectUrl(bytes, 'video/mp4');
      if (_blobUrl == null) {
        _showError('Failed to create video playback URL');
        return;
      }
      _controller = VideoPlayerController.networkUrl(Uri.parse(_blobUrl!));
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.file(_clip.filePath));
    }

    try {
      await _controller!.initialize();
      await _controller!.setLooping(false);
      await _controller!.play();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      _showError('Failed to play video: $e');
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  Future<void> _seekTo(Duration position) async {
    if (_controller == null || _isSeeking) return;
    _isSeeking = true;
    try {
      await _controller!.seekTo(position);
    } finally {
      _isSeeking = false;
    }
  }

  Future<void> _deleteClip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'DELETE CLIP?',
          style: AppTheme.displayFont(fontSize: 20),
        ),
        content: Text(
          'This will permanently delete the clip for ${_clip.date}.',
          style: AppTheme.monoFont(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: AppTheme.monoFont(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DELETE',
              style: AppTheme.monoFont(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageService.deleteClip(_clip.id);
      widget.onDelete?.call();
      if (mounted && !widget.embedded) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _removeTag(String tag) async {
    final updated = _clip.copyWith(
      tags: _clip.tags.where((t) => t != tag).toList(),
    );
    setState(() => _clip = updated);
    await widget.storageService.updateClip(updated);
  }

  Future<void> _addTag(String tag) async {
    final normalized = tag.trim().toLowerCase();
    if (normalized.isEmpty || _clip.tags.contains(normalized)) return;
    final updated = _clip.copyWith(
      tags: [..._clip.tags, normalized],
    );
    setState(() => _clip = updated);
    await widget.storageService.updateClip(updated);
  }

  void _showAddTagSheet() async {
    final existingTags = widget.storageService.allTags
        .where((t) => !_clip.tags.contains(t))
        .toList()
      ..sort();

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (context) {
        return _MultiTagSheet(
          existingTags: existingTags,
          clipTags: _clip.tags,
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      for (final tag in result) {
        await _addTag(tag);
      }
    }
  }

  Future<void> _scanFaces() async {
    final faceService = FaceService.instance;
    if (!faceService.isAvailable || _clip.thumbnailPath == null) return;

    final faces = await faceService.detectAndEmbed(_clip.thumbnailPath!);

    // Read thumbnail dimensions for accurate bounding box scaling
    try {
      final bytes = await FileStorage.readBytes(_clip.thumbnailPath!);
      if (bytes != null) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _thumbnailSize =
            Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        frame.image.dispose();
      }
    } catch (_) {}
    if (!mounted) return;
    final matched = <String>[];
    final matchedResults = <String, FaceDetectionResult>{};
    final unmatched = <FaceDetectionResult>[];

    for (final face in faces) {
      final result = faceService.findBestMatch(
        face.embedding,
        widget.storageService.knownPeople,
      );
      if (result != null) {
        matched.add(result.name);
        matchedResults[result.name] = face;
        // Auto-accumulate embeddings on confident match
        if (result.score > 0.75) {
          await widget.storageService
              .addPersonEmbedding(result.name, face.embedding);
        }
      } else {
        unmatched.add(face);
      }
    }

    if (!mounted) return;

    // Update detected faces and auto-tags
    if (matched.isNotEmpty) {
      final newFaces = {..._clip.detectedFaces, ...matched}.toList();
      final newTags = {..._clip.tags, ...matched}.toList();
      final updated = _clip.copyWith(detectedFaces: newFaces, tags: newTags);
      setState(() {
        _clip = updated;
        _unrecognizedFaces = unmatched;
        _detectedFaceResults = faces;
        _recognizedFaceResults = matchedResults;
      });
      await widget.storageService.updateClip(updated);
    } else {
      setState(() {
        _unrecognizedFaces = unmatched;
        _detectedFaceResults = faces;
      });
    }
  }

  Future<void> _nameUnrecognizedFace(FaceDetectionResult face) async {
    final controller = TextEditingController();

    // Crop face thumbnail from clip thumbnail
    Widget? faceThumbnail;
    if (_clip.thumbnailPath != null) {
      faceThumbnail = ClipRect(
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: ClipOval(
              child: ThumbnailImage(path: _clip.thumbnailPath!),
            ),
          ),
        ),
      );
    }

    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (faceThumbnail != null) ...[
                    faceThumbnail,
                    const SizedBox(width: 12),
                  ],
                  Text(
                    'NAME THIS PERSON',
                    style: AppTheme.pixelFont(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: AppTheme.monoFont(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter name...',
                        hintStyle: AppTheme.monoFont(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: theme.colorScheme.primary),
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color:
                                  theme.colorScheme.primary.withOpacity(0.5)),
                          borderRadius: BorderRadius.zero,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: theme.colorScheme.primary, width: 2),
                          borderRadius: BorderRadius.zero,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (value) =>
                          Navigator.pop(context, value.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, controller.text.trim()),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary),
                      ),
                      child: Icon(Icons.check,
                          size: 20, color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
              // Show existing people for quick selection
              if (widget.storageService.knownPeopleNames.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'KNOWN PEOPLE',
                  style: AppTheme.pixelFont(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.storageService.knownPeopleNames.map((n) {
                    final faceImagePath =
                        widget.storageService.getFaceImagePath(n);
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, n),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (faceImagePath != null) ...[
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: ClipOval(
                                  child: ThumbnailImage(path: faceImagePath),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              n,
                              style: AppTheme.monoFont(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );

    if (name == null || name.isEmpty) return;

    // Save embedding as reference for this person
    await widget.storageService.addPersonEmbedding(name, face.embedding);

    // Save face reference image
    if (_clip.thumbnailPath != null) {
      await widget.storageService
          .saveFaceImage(name, _clip.thumbnailPath!, face.boundingBox);
    }

    // Update clip with detected face
    final newFaces = [..._clip.detectedFaces, name];
    final newTags = {..._clip.tags, name}.toList();
    final updated = _clip.copyWith(detectedFaces: newFaces, tags: newTags);
    setState(() {
      _clip = updated;
      _unrecognizedFaces.remove(face);
      _recognizedFaceResults[name] = face;
    });
    await widget.storageService.updateClip(updated);
  }

  Future<void> _updateLocation(String label) async {
    final normalized = label.trim();
    final updated = _clip.copyWith(
      locationLabel: normalized.isEmpty ? null : normalized,
    );
    setState(() => _clip = updated);
    await widget.storageService.updateClip(updated);
  }

  void _showEditLocationSheet() {
    final controller = TextEditingController(text: _clip.locationLabel ?? '');
    final existingLocations = widget.storageService.allLocations.toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LOCATION',
                style: AppTheme.pixelFont(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: AppTheme.monoFont(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter location...',
                        hintStyle: AppTheme.monoFont(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: theme.colorScheme.primary),
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color:
                                  theme.colorScheme.primary.withOpacity(0.5)),
                          borderRadius: BorderRadius.zero,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: theme.colorScheme.primary, width: 2),
                          borderRadius: BorderRadius.zero,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (value) {
                        _updateLocation(value);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _updateLocation(controller.text);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary),
                      ),
                      child: Icon(Icons.check,
                          size: 20, color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
              if (existingLocations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'PREVIOUS LOCATIONS',
                  style: AppTheme.pixelFont(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: existingLocations.map((loc) {
                    return GestureDetector(
                      onTap: () {
                        _updateLocation(loc);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on,
                                size: 12, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              loc,
                              style: AppTheme.monoFont(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (_clip.locationLabel != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateLocation('');
                  },
                  child: Text(
                    'CLEAR LOCATION',
                    style: AppTheme.monoFont(
                      fontSize: 11,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _startTrim() async {
    if (_controller == null) return;
    final duration = await _ffmpegService.getVideoDuration(_clip.filePath);
    if (duration == null || duration < 0.5) {
      _showError('Video too short to trim');
      return;
    }
    setState(() {
      _isTrimming = true;
      _videoDuration = duration;
      _trimStart = 0;
      _trimDuration = (_clip.duration ?? 1.0).clamp(0.5, duration);
    });
    _controller?.pause();
  }

  void _cancelTrim() {
    setState(() => _isTrimming = false);
  }

  Future<void> _confirmTrim() async {
    setState(() => _isProcessingTrim = true);

    try {
      final tempPath = '${_clip.filePath}.trimmed.mp4';
      final result = await _ffmpegService.extractSegment(
        _clip.filePath,
        tempPath,
        _trimStart,
        duration: _trimDuration,
      );

      if (result == null) {
        _showError('Trim failed');
        setState(() => _isProcessingTrim = false);
        return;
      }

      // Replace original file
      await FileStorage.copyFile(tempPath, _clip.filePath);
      await FileStorage.deleteFile(tempPath);

      // Regenerate thumbnail
      if (_clip.thumbnailPath != null) {
        await _ffmpegService.generateThumbnail(
            _clip.filePath, _clip.thumbnailPath!);
      }

      // Update clip metadata with new duration
      final updated = _clip.copyWith(duration: _trimDuration);
      await widget.storageService.updateClip(updated);

      setState(() {
        _clip = updated;
        _isTrimming = false;
        _isProcessingTrim = false;
      });

      // Reinitialize player with the new file
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      await _initializePlayer();
    } catch (e) {
      _showError('Trim error: $e');
      setState(() => _isProcessingTrim = false);
    }
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
  void dispose() {
    if (_blobUrl != null) FileStorage.revokeObjectUrl(_blobUrl!);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.parse(_clip.date);

    final content = CrtOverlay(
      enabled: widget.storageService.getCrtEffects(),
      child: SafeArea(
        top: !widget.embedded,
        child: Stack(
          children: [
            // Video player
            if (_isInitialized && _controller != null)
              GestureDetector(
                onTap: _togglePlayPause,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: Stack(
                      children: [
                        VideoPlayer(_controller!),
                        // Face bounding boxes overlay
                        if (_detectedFaceResults.isNotEmpty)
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return CustomPaint(
                                  painter: _FaceBoundingBoxPainter(
                                    faces: _detectedFaceResults,
                                    recognizedNames: _recognizedFaceResults,
                                    unrecognizedFaces: _unrecognizedFaces,
                                    imageSize: _thumbnailSize ??
                                        _controller!.value.size,
                                    displaySize: Size(constraints.maxWidth,
                                        constraints.maxHeight),
                                    primaryColor: theme.colorScheme.primary,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),

            // Play/pause indicator
            if (_isInitialized && !_controller!.value.isPlaying)
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: theme.colorScheme.primary,
                      size: 40,
                    ),
                  ),
                ),
              ),

            // Top bar (only when not embedded — DayViewScreen provides its own AppBar)
            if (!widget.embedded)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Column(
                        children: [
                          Text(
                            DateFormat('EEEE').format(date).toUpperCase(),
                            style: AppTheme.pixelFont(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy').format(date),
                            style: AppTheme.monoFont(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!kIsWeb)
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.white),
                              onPressed: () async {
                                await Share.shareXFiles([XFile(_clip.filePath)]);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white),
                            onPressed: _deleteClip,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Delete + share buttons when embedded (top-right corner)
            if (widget.embedded)
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!kIsWeb) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.share,
                              color: Colors.white, size: 20),
                          onPressed: () async {
                            await Share.shareXFiles([XFile(_clip.filePath)]);
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 20),
                        onPressed: _deleteClip,
                      ),
                    ),
                  ],
                ),
              ),

            // Trim overlay
            if (_isTrimming)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    border: Border(
                      top: BorderSide(
                          color: theme.colorScheme.primary, width: 2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TRIM CLIP',
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
                            'START',
                            style: AppTheme.monoFont(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _trimStart,
                              min: 0,
                              max: (_videoDuration - _trimDuration)
                                  .clamp(0, _videoDuration),
                              onChanged: (v) {
                                setState(() => _trimStart = v);
                                _seekTo(Duration(
                                    milliseconds: (v * 1000).toInt()));
                              },
                              activeColor: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${_trimStart.toStringAsFixed(1)}s',
                            style: AppTheme.monoFont(fontSize: 11),
                          ),
                        ],
                      ),
                      // Duration slider
                      Row(
                        children: [
                          Text(
                            'LENGTH',
                            style: AppTheme.monoFont(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _trimDuration,
                              min: 0.5,
                              max: (_videoDuration - _trimStart)
                                  .clamp(0.5, _videoDuration),
                              onChanged: (v) =>
                                  setState(() => _trimDuration = v),
                              activeColor: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${_trimDuration.toStringAsFixed(1)}s',
                            style: AppTheme.monoFont(fontSize: 11),
                          ),
                        ],
                      ),
                      // Duration presets
                      Wrap(
                        spacing: 8,
                        children: [0.5, 1.0, 1.5, 2.0, 3.0]
                            .where((d) => d <= _videoDuration)
                            .map((d) {
                          final isSelected = (_trimDuration - d).abs() < 0.05;
                          return GestureDetector(
                            onTap: () => setState(() => _trimDuration =
                                d.clamp(0.5, _videoDuration - _trimStart)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                border: Border.all(
                                    color: theme.colorScheme.primary),
                              ),
                              child: Text(
                                '${d}s',
                                style: AppTheme.monoFont(
                                  fontSize: 12,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Action buttons
                      if (_isProcessingTrim)
                        Text(
                          'PROCESSING...',
                          style: AppTheme.monoFont(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _cancelTrim,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.3)),
                                ),
                                child: Text(
                                  'CANCEL',
                                  style: AppTheme.monoFont(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: _confirmTrim,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  border: Border.all(
                                      color: theme.colorScheme.primary),
                                ),
                                child: Text(
                                  'APPLY TRIM',
                                  style: AppTheme.monoFont(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            // Bottom info (hidden during trim)
            if (!_isTrimming)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Import action buttons (DONE / ADD MORE)
                      if (widget.showImportActions) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context, 'done'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  border: Border.all(
                                      color: theme.colorScheme.primary),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check,
                                        size: 16,
                                        color: theme.colorScheme.onPrimary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'DONE',
                                      style: AppTheme.monoFont(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => Navigator.pop(context, 'add_more'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: theme.colorScheme.primary),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add,
                                        size: 16,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ADD MORE',
                                      style: AppTheme.monoFont(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Tags
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          ..._clip.tags.map((tag) => GestureDetector(
                                onTap: () => _removeTag(tag),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    border: Border.all(
                                        color: theme.colorScheme.primary),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tag,
                                        style: AppTheme.monoFont(
                                          fontSize: 12,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.close,
                                          size: 12,
                                          color: theme.colorScheme.primary),
                                    ],
                                  ),
                                ),
                              )),
                          GestureDetector(
                            onTap: _showAddTagSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add,
                                      size: 12,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'TAG',
                                    style: AppTheme.monoFont(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Detected faces
                      if (_clip.detectedFaces.isNotEmpty ||
                          _unrecognizedFaces.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            ..._clip.detectedFaces.map((name) {
                              final faceImagePath =
                                  widget.storageService.getFaceImagePath(name);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  border: Border.all(
                                      color: theme.colorScheme.primary),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (faceImagePath != null) ...[
                                      CircleAvatar(
                                        radius: 8,
                                        child: ClipOval(
                                          child: ThumbnailImage(
                                              path: faceImagePath),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ] else ...[
                                      Icon(Icons.face,
                                          size: 14,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      name,
                                      style: AppTheme.monoFont(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            ..._unrecognizedFaces.map((face) => GestureDetector(
                                  onTap: () => _nameUnrecognizedFace(face),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      border: Border.all(
                                        color: Colors.amber.withOpacity(0.7),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.face,
                                            size: 14, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          'NAME?',
                                          style: AppTheme.monoFont(
                                            fontSize: 12,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ],
                      // Scan faces button
                      if (_clip.detectedFaces.isEmpty &&
                          _unrecognizedFaces.isEmpty) ...[
                        const SizedBox(height: 8),
                        if (FaceService.instance.isAvailable)
                          GestureDetector(
                            onTap: _scanFaces,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.face_retouching_natural,
                                      size: 14,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'SCAN FACES',
                                    style: AppTheme.monoFont(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              border: Border.all(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.face_retouching_natural,
                                    size: 14,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.3)),
                                const SizedBox(width: 4),
                                Text(
                                  'FACE SCAN UNAVAILABLE',
                                  style: AppTheme.monoFont(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _InfoChip(
                            icon: _getTypeIcon(_clip.type),
                            label: _getTypeLabel(_clip.type),
                          ),
                          const SizedBox(width: 16),
                          _InfoChip(
                            icon: Icons.timer,
                            label:
                                '${_clip.duration?.toStringAsFixed(1) ?? "1.0"}s',
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: _showEditLocationSheet,
                            child: _InfoChip(
                              icon: Icons.location_on,
                              label: _clip.locationLabel ?? 'ADD',
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: _startTrim,
                            child: const _InfoChip(
                              icon: Icons.content_cut,
                              label: 'TRIM',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Container(
        color: Colors.black,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: content,
    );
  }

  IconData _getTypeIcon(ClipType type) {
    switch (type) {
      case ClipType.video:
        return Icons.videocam;
      case ClipType.photo:
        return Icons.camera_alt;
      case ClipType.imported:
        return Icons.photo_library;
    }
  }

  String _getTypeLabel(ClipType type) {
    switch (type) {
      case ClipType.video:
        return 'RECORDED';
      case ClipType.photo:
        return 'PHOTO';
      case ClipType.imported:
        return 'IMPORTED';
    }
  }
}

class _MultiTagSheet extends StatefulWidget {
  final List<String> existingTags;
  final List<String> clipTags;

  const _MultiTagSheet({
    required this.existingTags,
    required this.clipTags,
  });

  @override
  State<_MultiTagSheet> createState() => _MultiTagSheetState();
}

class _MultiTagSheetState extends State<_MultiTagSheet> {
  final Set<String> _pendingTags = {};
  final List<String> _newCustomTags = [];
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addCustomTag(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return;
    if (widget.clipTags.contains(normalized)) return;
    // If it matches an existing tag, toggle it on instead of creating a duplicate
    if (widget.existingTags.contains(normalized)) {
      setState(() {
        _pendingTags.add(normalized);
      });
    } else if (!_newCustomTags.contains(normalized)) {
      setState(() {
        _newCustomTags.add(normalized);
        _pendingTags.add(normalized);
      });
    }
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADD TAGS',
            style: AppTheme.pixelFont(
              fontSize: 11,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: AppTheme.monoFont(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter new tag...',
                    hintStyle: AppTheme.monoFont(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.zero,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.5)),
                      borderRadius: BorderRadius.zero,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: theme.colorScheme.primary, width: 2),
                      borderRadius: BorderRadius.zero,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (value) => _addCustomTag(value),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _addCustomTag(_controller.text),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.primary),
                  ),
                  child: Icon(Icons.add,
                      size: 20, color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
          if (_newCustomTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'NEW TAGS',
              style: AppTheme.pixelFont(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _newCustomTags.map((tag) {
                final selected = _pendingTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _pendingTags.remove(tag);
                      } else {
                        _pendingTags.add(tag);
                      }
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.check,
                                size: 14, color: theme.colorScheme.onPrimary),
                          ),
                        Text(
                          tag,
                          style: AppTheme.monoFont(
                            fontSize: 12,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (widget.existingTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'EXISTING TAGS',
              style: AppTheme.pixelFont(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.existingTags.map((tag) {
                final selected = _pendingTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _pendingTags.remove(tag);
                      } else {
                        _pendingTags.add(tag);
                      }
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.check,
                                size: 14, color: theme.colorScheme.onPrimary),
                          ),
                        Text(
                          tag,
                          style: AppTheme.monoFont(
                            fontSize: 12,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: RetroButton(
              onPressed: () => Navigator.pop(context, _pendingTags),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check,
                      size: 18, color: theme.colorScheme.onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'DONE${_pendingTags.isNotEmpty ? " (${_pendingTags.length})" : ""}',
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.monoFont(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to draw face bounding boxes over the video
class _FaceBoundingBoxPainter extends CustomPainter {
  final List<FaceDetectionResult> faces;
  final Map<String, FaceDetectionResult> recognizedNames;
  final List<FaceDetectionResult> unrecognizedFaces;
  final Size imageSize;
  final Size displaySize;
  final Color primaryColor;

  _FaceBoundingBoxPainter({
    required this.faces,
    required this.recognizedNames,
    required this.unrecognizedFaces,
    required this.imageSize,
    required this.displaySize,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (final face in faces) {
      final isUnrecognized = unrecognizedFaces.contains(face);
      final color = isUnrecognized ? Colors.amber : primaryColor;

      // Find name for recognized faces
      String? name;
      for (final entry in recognizedNames.entries) {
        if (entry.value == face) {
          name = entry.key;
          break;
        }
      }

      final rect = Rect.fromLTWH(
        face.boundingBox.left * scaleX,
        face.boundingBox.top * scaleY,
        face.boundingBox.width * scaleX,
        face.boundingBox.height * scaleY,
      );

      // Draw rounded rect outline
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );

      // Draw name label above box
      final labelText = name ?? '?';
      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Background for label
      final labelBg = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      canvas.drawRect(labelBg, Paint()..color = color.withOpacity(0.8));
      textPainter.paint(canvas, Offset(labelBg.left + 4, labelBg.top + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _FaceBoundingBoxPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.recognizedNames != recognizedNames;
  }
}
