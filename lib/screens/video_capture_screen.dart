import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/ffmpeg_service.dart';
import '../models/clip.dart';
import '../widgets/crt_effects.dart';
import '../utils/location_util.dart';
import '../services/face_service.dart';
import '../platform/file_storage.dart';

class VideoCaptureScreen extends StatefulWidget {
  final StorageService storageService;
  final String date;

  const VideoCaptureScreen({
    super.key,
    required this.storageService,
    required this.date,
  });

  @override
  State<VideoCaptureScreen> createState() => _VideoCaptureScreenState();
}

class _VideoCaptureScreenState extends State<VideoCaptureScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  VideoPlayerController? _previewController;

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _hasRecorded = false;
  String? _recordedPath;
  XFile? _recordedFile;
  bool _flashOn = false;
  bool _isProcessing = false;
  int _cameraIndex = 0;
  List<CameraDescription> _cameras = [];

  // Recording duration tracking
  double _recordingDuration = 0;
  Timer? _recordingTimer;
  static const double _maxRecordingDuration = 10.0;

  // Trim selection
  double _trimStart = 0;
  double _selectedDuration = 1.0;
  double? _actualDuration;
  bool _isSeeking = false;

  late AnimationController _pulseController;
  final _ffmpegService = FFmpegService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No cameras available');
        return;
      }

      await _setupCamera(_cameras[_cameraIndex]);
    } catch (e) {
      _showError('Camera error: $e');
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  void _toggleCamera() async {
    if (_cameras.length < 2) return;

    setState(() => _isInitialized = false);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _setupCamera(_cameras[_cameraIndex]);
  }

  void _toggleFlash() async {
    if (_controller == null) return;

    setState(() => _flashOn = !_flashOn);
    if (!kIsWeb) {
      await _controller!.setFlashMode(
        _flashOn ? FlashMode.torch : FlashMode.off,
      );
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || _isRecording) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Track recording duration
      _recordingTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) {
        setState(() {
          _recordingDuration += 0.1;
        });

        // Auto-stop at max duration
        if (_recordingDuration >= _maxRecordingDuration) {
          _stopRecording();
        }
      });
    } catch (e) {
      _showError('Recording failed: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final file = await _controller!.stopVideoRecording();

      // Get actual duration
      final duration = await _ffmpegService.getVideoDuration(file.path);

      // Initialize preview player (blob URL on web, file:// URI on native)
      _previewController?.dispose();
      final previewUri =
          kIsWeb ? Uri.parse(file.path) : Uri.file(file.path);
      _previewController = VideoPlayerController.networkUrl(previewUri);
      await _previewController!.initialize();

      setState(() {
        _isRecording = false;
        _hasRecorded = true;
        _recordedPath = file.path;
        _recordedFile = file;
        _actualDuration = duration ?? _recordingDuration;
        _trimStart = 0;
        _selectedDuration = 1.0;
      });
    } catch (e) {
      _showError('Stop recording failed: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _seekTo(double seconds) async {
    if (_previewController == null || _isSeeking) return;

    _isSeeking = true;
    try {
      await _previewController!.pause();
      await _previewController!
          .seekTo(Duration(milliseconds: (seconds * 1000).toInt()));

      // Small delay for codec to settle
      await Future.delayed(const Duration(milliseconds: 50));
    } finally {
      _isSeeking = false;
    }
  }

  void _playPreview() async {
    if (_previewController == null) return;

    await _seekTo(_trimStart);
    await _previewController!.play();

    // Stop after selected duration
    Future.delayed(Duration(milliseconds: (_selectedDuration * 1000).toInt()),
        () {
      if (mounted &&
          _previewController != null &&
          _previewController!.value.isPlaying) {
        _previewController!.pause();
      }
    });
  }

  Future<void> _saveClip() async {
    if (_recordedPath == null) return;

    setState(() => _isProcessing = true);

    try {
      // Capture GPS in parallel with video processing
      final locationFuture = widget.storageService.getCaptureLocation()
          ? LocationUtil.getCurrentLocation()
          : Future.value(null);

      final clipId = widget.storageService.generateId();
      final outputPath = widget.storageService.getClipPath(clipId);
      final thumbnailPath = widget.storageService.getThumbnailPath(clipId);

      // On web the recorded path is a blob URL; write bytes to OPFS first
      String inputPath;
      if (kIsWeb) {
        inputPath = 'opfs://temp_rec_$clipId.mp4';
        final bytes = await _recordedFile!.readAsBytes();
        await FileStorage.writeBytes(inputPath, bytes);
      } else {
        inputPath = _recordedPath!;
      }

      // Extract selected segment
      final result = await _ffmpegService.extractSegment(
        inputPath,
        outputPath,
        _trimStart,
        duration: _selectedDuration,
      );

      // Clean up temp input file
      await FileStorage.deleteFile(kIsWeb ? inputPath : _recordedPath!)
          .catchError((_) {});

      if (result == null) {
        _showError('Failed to process video');
        setState(() => _isProcessing = false);
        return;
      }

      await _ffmpegService.generateThumbnail(outputPath, thumbnailPath);

      final location = await locationFuture;

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

      if (location?.label != null && location!.label!.isNotEmpty) {
        autoTags.add(location.label!);
      }

      final clip = Clip(
        id: clipId,
        date: widget.date,
        filePath: outputPath,
        thumbnailPath: thumbnailPath,
        type: ClipType.video,
        createdAt: DateTime.now(),
        capturedAt: DateTime.now(),
        duration: _selectedDuration,
        latitude: location?.latitude,
        longitude: location?.longitude,
        locationLabel: location?.label,
        detectedFaces: detectedFaces,
        tags: autoTags,
      );

      await widget.storageService.addClip(clip);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Save failed: $e');
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  void _retake() {
    _previewController?.dispose();
    _previewController = null;

    if (_recordedPath != null) {
      if (kIsWeb) {
        FileStorage.revokeObjectUrl(_recordedPath!);
      } else {
        FileStorage.deleteFile(_recordedPath!).catchError((_) {});
      }
    }
    setState(() {
      _hasRecorded = false;
      _recordedPath = null;
      _recordedFile = null;
      _actualDuration = null;
    });
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
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _controller?.dispose();
    _previewController?.dispose();
    super.dispose();
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
        backgroundColor: Colors.black,
        body: SafeArea(
        child: Stack(
          children: [
            // Camera preview or recorded video preview
            if (_hasRecorded && _previewController != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _playPreview,
                  child: _previewController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _previewController!.value.aspectRatio,
                          child: VideoPlayer(_previewController!),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_isInitialized && _controller != null)
              Positioned.fill(
                child: CameraPreview(_controller!),
              )
            else
              const Center(child: CircularProgressIndicator()),

            // CRT overlay
            if (_isInitialized && widget.storageService.getCrtEffects())
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ScanlinePainter(intensity: 0.02),
                  ),
                ),
              ),

            // Top bar
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
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Column(
                      children: [
                        if (_isRecording)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const RecordingIndicator(size: 12),
                              const SizedBox(width: 8),
                              Text(
                                'REC ${_recordingDuration.toStringAsFixed(1)}s',
                                style: AppTheme.monoFont(
                                  fontSize: 14,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            widget.date,
                            style: AppTheme.monoFont(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Recording progress bar
            if (_isRecording)
              Positioned(
                top: 80,
                left: 32,
                right: 32,
                child: RetroProgressBar(
                  value: _recordingDuration / _maxRecordingDuration,
                  height: 8,
                  color: theme.colorScheme.primary,
                ),
              ),

            // Bottom controls
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
                      Colors.black.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: _hasRecorded
                    ? _buildReviewControls()
                    : _buildCaptureControls(),
              ),
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
                          'PROCESSING...',
                          style: AppTheme.monoFont(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCaptureControls() {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isRecording)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'TAP TO START • TAP AGAIN TO STOP\nMAX ${_maxRecordingDuration.toInt()} SECONDS',
              style: AppTheme.monoFont(
                fontSize: 11,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Flash toggle
            RetroIconButton(
              icon: _flashOn ? Icons.flash_on : Icons.flash_off,
              onPressed: _isRecording ? null : _toggleFlash,
              color: _flashOn ? Colors.amber : Colors.white,
            ),

            // Record button
            GestureDetector(
              onTap: _isRecording ? _stopRecording : _startRecording,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale =
                      _isRecording ? 1.0 + _pulseController.value * 0.1 : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: _isRecording ? 30 : 60,
                          height: _isRecording ? 30 : 60,
                          decoration: BoxDecoration(
                            shape: _isRecording
                                ? BoxShape.rectangle
                                : BoxShape.circle,
                            borderRadius:
                                _isRecording ? BorderRadius.circular(4) : null,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Camera flip
            RetroIconButton(
              icon: Icons.flip_camera_ios,
              onPressed: _isRecording
                  ? null
                  : (_cameras.length > 1 ? _toggleCamera : null),
              color: Colors.white,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewControls() {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trim controls (only if video is longer than 1 second)
        if (_actualDuration != null && _actualDuration! > 1.0) ...[
          Text(
            'SELECT ${_selectedDuration.toStringAsFixed(1)}s SEGMENT',
            style: AppTheme.pixelFont(
              fontSize: 11,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          // Duration selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [1.0, 2.0, 3.0, 5.0]
                .where((d) => d <= _actualDuration!)
                .map((d) {
              final isSelected = _selectedDuration == d;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDuration = d;
                      final maxStart = _actualDuration! - d;
                      if (_trimStart > maxStart) {
                        _trimStart = maxStart.clamp(0, double.infinity);
                      }
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          const SizedBox(height: 12),

          // Trim slider
          Row(
            children: [
              Text(
                _formatTime(_trimStart),
                style: AppTheme.monoFont(fontSize: 11, color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  value: _trimStart,
                  min: 0,
                  max: (_actualDuration! - _selectedDuration)
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
                style: AppTheme.monoFont(fontSize: 11, color: Colors.white),
              ),
            ],
          ),

          GestureDetector(
            onTap: _playPreview,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow,
                      color: theme.colorScheme.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'PREVIEW',
                    style: AppTheme.monoFont(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            RetroButton(
              onPressed: _retake,
              color: Colors.grey[800],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'RETAKE',
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            RetroButton(
              onPressed: _isProcessing ? null : _saveClip,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'SAVE',
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

class _ScanlinePainter extends CustomPainter {
  final double intensity;

  _ScanlinePainter({this.intensity = 0.03});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(intensity)
      ..strokeWidth = 1;

    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
