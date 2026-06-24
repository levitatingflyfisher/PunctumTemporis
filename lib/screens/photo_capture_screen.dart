import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/ffmpeg_service.dart';
import '../models/clip.dart';
import '../widgets/crt_effects.dart';
import '../utils/location_util.dart';
import '../services/face_service.dart';
import '../platform/file_storage.dart';

class PhotoCaptureScreen extends StatefulWidget {
  final StorageService storageService;
  final String date;

  const PhotoCaptureScreen({
    super.key,
    required this.storageService,
    required this.date,
  });

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _hasPhoto = false;
  String? _photoPath;
  XFile? _photoFile;
  Uint8List? _photoBytes;
  bool _flashOn = false;
  bool _isProcessing = false;
  int _cameraIndex = 0;
  List<CameraDescription> _cameras = [];

  final _ffmpegService = FFmpegService();

  @override
  void initState() {
    super.initState();
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
        _flashOn ? FlashMode.always : FlashMode.off,
      );
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null) return;

    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      setState(() {
        _hasPhoto = true;
        _photoPath = file.path;
        _photoFile = file;
        _photoBytes = bytes;
      });
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _savePhoto() async {
    if (_photoPath == null) return;

    setState(() => _isProcessing = true);

    try {
      // Capture GPS in parallel with photo processing
      final locationFuture = widget.storageService.getCaptureLocation()
          ? LocationUtil.getCurrentLocation()
          : Future.value(null);

      final clipId = widget.storageService.generateId();
      final outputPath = widget.storageService.getClipPath(clipId);
      final thumbnailPath = widget.storageService.getThumbnailPath(clipId);

      // On web the photo path is a blob URL; write bytes to OPFS first
      String inputPath;
      if (kIsWeb) {
        inputPath = 'opfs://temp_photo_$clipId.jpg';
        await FileStorage.writeBytes(inputPath, _photoBytes!);
      } else {
        inputPath = _photoPath!;
      }

      // Convert photo to 1-second video
      final result = await _ffmpegService.photoToVideo(inputPath, outputPath);

      // Clean up temp input on web
      if (kIsWeb) {
        await FileStorage.deleteFile(inputPath).catchError((_) {});
      }

      if (result == null) {
        _showError('Failed to convert photo to video');
        setState(() => _isProcessing = false);
        return;
      }

      // Thumbnail: write the captured bytes directly (avoids dart:io File.copy)
      await FileStorage.writeBytes(thumbnailPath, _photoBytes!);

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

      // Create clip record
      final clip = Clip(
        id: clipId,
        date: widget.date,
        filePath: outputPath,
        thumbnailPath: thumbnailPath,
        type: ClipType.photo,
        createdAt: DateTime.now(),
        capturedAt: DateTime.now(),
        duration: 1.0,
        latitude: location?.latitude,
        longitude: location?.longitude,
        locationLabel: location?.label,
        detectedFaces: detectedFaces,
        tags: autoTags,
      );

      await widget.storageService.addClip(clip);

      // Clean up the native temp photo file (on web it's a blob URL, skip)
      if (!kIsWeb && _photoPath != null) {
        await FileStorage.deleteFile(_photoPath!).catchError((_) {});
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Save failed: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _retake() {
    if (!kIsWeb && _photoPath != null) {
      FileStorage.deleteFile(_photoPath!).catchError((_) {});
    }
    setState(() {
      _hasPhoto = false;
      _photoPath = null;
      _photoFile = null;
      _photoBytes = null;
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
    _controller?.dispose();
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
              // Camera preview or captured photo
              if (_hasPhoto && _photoBytes != null)
              Positioned.fill(
                child: Image.memory(
                  _photoBytes!,
                  fit: BoxFit.cover,
                ),
              )
            else if (_isInitialized && _controller != null)
              Positioned.fill(
                child: CameraPreview(_controller!),
              )
            else
              const Center(
                child: CircularProgressIndicator(),
              ),

            // CRT overlay
            if (widget.storageService.getCrtEffects())
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
                        Text(
                          'PHOTO',
                          style: AppTheme.pixelFont(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          widget.date,
                          style: AppTheme.monoFont(
                            fontSize: 12,
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

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: _hasPhoto
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
                          'CONVERTING TO VIDEO...',
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Flash toggle
        RetroIconButton(
          icon: _flashOn ? Icons.flash_on : Icons.flash_off,
          onPressed: _toggleFlash,
          color: _flashOn ? Colors.amber : Colors.white,
        ),

        // Capture button
        GestureDetector(
          onTap: _takePhoto,
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),

        // Camera flip
        RetroIconButton(
          icon: Icons.flip_camera_ios,
          onPressed: _cameras.length > 1 ? _toggleCamera : null,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _buildReviewControls() {
    return Row(
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
          onPressed: _isProcessing ? null : _savePhoto,
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
    );
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
