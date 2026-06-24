import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../platform/file_storage.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
import '../widgets/crt_effects.dart';

class BackupRestoreScreen extends StatefulWidget {
  final StorageService storageService;

  const BackupRestoreScreen({
    super.key,
    required this.storageService,
  });

  static const cancelRestoreWarning =
      'Restore may be partial. Corrupt data is unlikely but possible. Continue?';

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  late final BackupService _backupService;

  bool _isBackingUp = false;
  bool _isRestoring = false;
  double _progress = 0;
  String? _statusMessage;
  int? _estimatedSize;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(widget.storageService);
    _loadEstimatedSize();
  }

  Future<void> _loadEstimatedSize() async {
    final size = await _backupService.getBackupSize();
    if (mounted) {
      setState(() => _estimatedSize = size);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _createBackup() async {
    // On native: write to app-private storage first (no permission needed),
    // then share via system sheet. Direct external writes fail on Android 11+
    // scoped storage even after the user grants SAF folder access.
    String outputPath = '';
    if (!kIsWeb) {
      final appDir = await FileStorage.appDocDir();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      outputPath = '$appDir/onesecond_backup_$timestamp.zip';
    }

    setState(() {
      _isBackingUp = true;
      _progress = 0;
      _statusMessage = 'Creating backup...';
    });

    try {
      await _backupService.createBackup(
        outputPath,
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              if (progress < 0.8) {
                _statusMessage = 'Packing files...';
              } else if (progress < 0.9) {
                _statusMessage = 'Compressing...';
              } else {
                _statusMessage = 'Writing backup...';
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _statusMessage = null;
        });
        if (kIsWeb) {
          _showSuccess('Backup downloaded');
        } else {
          final fileName = outputPath.split('/').last;
          await _showBackupOptions(outputPath, fileName);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _statusMessage = null;
        });
        _showError('Backup failed: $e');
      }
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: kIsWeb, // fetch bytes directly on web
    );
    if (result == null) return;

    Uint8List? bytes;
    if (kIsWeb) {
      bytes = result.files.single.bytes;
    } else {
      final path = result.files.single.path;
      if (path == null) return;
      bytes = await FileStorage.readBytes(path);
    }

    if (bytes == null) {
      _showError('Could not read backup file');
      return;
    }

    // Validate first
    setState(() {
      _statusMessage = 'Validating backup...';
    });

    try {
      final info = await _backupService.validateBackup(bytes);

      if (!mounted) return;

      // Show confirmation dialog
      final restoreMode = await showDialog<String>(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text(
              'RESTORE BACKUP',
              style: AppTheme.displayFont(fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${info.clipCount} clips',
                  style: AppTheme.monoFont(fontSize: 14),
                ),
                if (info.dateRange != null)
                  Text(
                    info.dateRange!,
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                Text(
                  _formatBytes(info.sizeBytes),
                  style: AppTheme.monoFont(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                if (info.faceCount > 0)
                  Text(
                    '${info.faceCount} face references',
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'How should this be restored?',
                  style: AppTheme.monoFont(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text('CANCEL', style: AppTheme.monoFont(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'merge'),
                child: Text(
                  'MERGE',
                  style: AppTheme.monoFont(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'replace'),
                child: Text(
                  'REPLACE ALL',
                  style: AppTheme.monoFont(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          );
        },
      );

      if (restoreMode == null) {
        setState(() => _statusMessage = null);
        return;
      }

      // Second confirmation for the destructive REPLACE ALL path
      if (restoreMode == 'replace') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            title: Text(
              'REPLACE ALL DATA?',
              style: AppTheme.displayFont(fontSize: 16),
            ),
            content: Text(
              'This will permanently delete ALL current clips and replace them '
              'with the backup. This cannot be undone.',
              style: AppTheme.monoFont(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('CANCEL', style: AppTheme.monoFont(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'YES, REPLACE ALL',
                  style: AppTheme.monoFont(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          if (mounted) setState(() => _statusMessage = null);
          return;
        }
      }

      setState(() {
        _isRestoring = true;
        _progress = 0;
        _statusMessage = 'Restoring...';
      });

      await _backupService.restoreBackup(
        bytes,
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              if (progress < 0.8) {
                _statusMessage = 'Extracting files...';
              } else if (progress < 0.95) {
                _statusMessage = 'Updating metadata...';
              } else {
                _statusMessage = 'Reloading...';
              }
            });
          }
        },
        replace: restoreMode == 'replace',
      );

      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusMessage = null;
        });
        _showSuccess('Backup restored successfully');
        _loadEstimatedSize();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusMessage = null;
        });
        _showError('Restore failed: $e');
      }
    }
  }

  Future<void> _cancelRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text('CANCEL RESTORE?', style: AppTheme.pixelFont(fontSize: 12)),
        content: Text(
          BackupRestoreScreen.cancelRestoreWarning,
          style: AppTheme.monoFont(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('KEEP WAITING', style: AppTheme.monoFont(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'LEAVE ANYWAY',
              style: AppTheme.monoFont(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  Future<void> _showBackupOptions(String outputPath, String fileName) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BACKUP CREATED',
                style: AppTheme.pixelFont(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fileName,
                style: AppTheme.monoFont(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.folder_open, color: theme.colorScheme.primary),
                title: Text('Save to Device', style: AppTheme.displayFont(fontSize: 15)),
                subtitle: Text('Choose a folder on your device', style: AppTheme.monoFont(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'save'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.share, color: theme.colorScheme.primary),
                title: Text('Share', style: AppTheme.displayFont(fontSize: 15)),
                subtitle: Text('Send via app, cloud, or email', style: AppTheme.monoFont(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'save') {
      final bytes = await FileStorage.readBytes(outputPath);
      if (bytes == null) {
        _showError('Could not read backup file');
        return;
      }
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (mounted && savedPath != null) {
        _showSuccess('Backup saved');
      }
    } else if (action == 'share') {
      await Share.shareXFiles(
        [XFile(outputPath)],
        subject: 'One Second A Day Backup',
      );
    }
  }

  Future<void> _shareCompilation(String filePath) async {
    if (!await FileStorage.exists(filePath)) {
      _showError('File not found');
      return;
    }
    if (kIsWeb) {
      final bytes = await FileStorage.readBytes(filePath);
      if (bytes == null) {
        _showError('File not found');
        return;
      }
      final filename = filePath.split('/').last;
      await FileStorage.downloadFile(bytes, filename, 'video/mp4');
    } else {
      await Share.shareXFiles([XFile(filePath)]);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compilations = widget.storageService.compilations;

    return PopScope(
      canPop: !_isBackingUp && !_isRestoring,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Operation in progress — please wait')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'BACKUP & RESTORE',
            style: AppTheme.pixelFont(fontSize: 12),
          ),
        ),
      body: CrtOverlay(
        enabled: widget.storageService.getCrtEffects(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // BACKUP section
            _buildSectionHeader('BACKUP'),

            RetroCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Backup',
                              style: AppTheme.displayFont(
                                fontSize: 16,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              kIsWeb
                                  ? 'Download ZIP of all clips and metadata'
                                  : 'Save all clips, thumbnails, and metadata',
                              style: AppTheme.monoFont(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Estimated size: ${_estimatedSize != null ? _formatBytes(_estimatedSize!) : "calculating..."}',
                        style: AppTheme.monoFont(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.storageService.totalClips} clips',
                        style: AppTheme.monoFont(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isBackingUp) ...[
                    RetroProgressBar(value: _progress, height: 16),
                    const SizedBox(height: 8),
                    Text(
                      '${_statusMessage ?? ""} ${(_progress * 100).toInt()}%',
                      style: AppTheme.monoFont(fontSize: 12),
                    ),
                  ] else
                    Center(
                      child: RetroButton(
                        onPressed: _createBackup,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_alt, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              kIsWeb ? 'DOWNLOAD BACKUP' : 'CREATE BACKUP',
                              style: AppTheme.monoFont(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // RESTORE section
            _buildSectionHeader('RESTORE'),

            RetroCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restore, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restore from Backup',
                              style: AppTheme.displayFont(
                                fontSize: 16,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Load clips from a backup ZIP',
                              style: AppTheme.monoFont(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isRestoring) ...[
                    RetroProgressBar(value: _progress, height: 16),
                    const SizedBox(height: 8),
                    Text(
                      '${_statusMessage ?? ""} ${(_progress * 100).toInt()}%',
                      style: AppTheme.monoFont(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _cancelRestore,
                        child: Text(
                          'CANCEL',
                          style: AppTheme.monoFont(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Center(
                      child: RetroButton(
                        onPressed: _restoreBackup,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.upload_file, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'SELECT BACKUP FILE',
                              style: AppTheme.monoFont(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // SHARE / DOWNLOAD section
            _buildSectionHeader(kIsWeb ? 'DOWNLOAD COMPILATIONS' : 'SHARE COMPILATIONS'),

            if (compilations.isEmpty)
              Text(
                'No compilations yet',
                style: AppTheme.monoFont(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              )
            else
              ...compilations.reversed.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RetroCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.movie,
                              color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.title,
                                  style: AppTheme.displayFont(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '${c.clipIds.length} clips',
                                  style: AppTheme.monoFont(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              kIsWeb ? Icons.download : Icons.share,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            onPressed: () => _shareCompilation(c.filePath),
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTheme.pixelFont(
          fontSize: 11,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
