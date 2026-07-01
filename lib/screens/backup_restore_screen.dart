import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart'
    show
        BackupVault,
        FileVaultStore,
        createPlatformVaultFileApi;
import '../platform/file_storage.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
import '../widgets/crt_effects.dart';
import '../widgets/metadata_snapshots_section.dart';

class BackupRestoreScreen extends StatefulWidget {
  final StorageService storageService;

  const BackupRestoreScreen({
    super.key,
    required this.storageService,
  });

  static const cancelRestoreWarning =
      'Restore may be partial. Corrupt data is unlikely but possible. Continue?';

  // Exactly true, calmly said: a restore only rewrites the journal index
  // and settings. Clip FILES are never deleted (see BackupService.vault —
  // UUID names don't collide, old metadata simply re-adopts them), so
  // clips missing from the backup leave the app's view but stay on disk.
  // Copy claiming "ALL data" is replaced would be a lie in both
  // directions.
  static const replaceAllTitle = 'REPLACE FROM BACKUP?';

  static const replaceAllWarning =
      'Your journal index and settings will be replaced with what is in '
      'the backup. Clips that are not in the backup will no longer appear '
      'in the app, but their video files stay on your device. A snapshot '
      'of your current journal index is saved to Previous snapshots '
      'first, so you can roll back.';

  // Legacy v1 archives carry no settings.json, so a replace-mode restore
  // of one leaves current settings exactly as they are. Promising
  // "settings will be replaced" there would be a lie in the other
  // direction.
  static const replaceAllWarningNoSettings =
      'Your journal index will be replaced with what is in the backup. '
      'This older backup contains no settings, so your current settings '
      'stay as they are. Clips that are not in the backup will no longer '
      'appear in the app, but their video files stay on your device. A '
      'snapshot of your current journal index is saved to Previous '
      'snapshots first, so you can roll back.';

  static const replaceAllConfirmLabel = 'YES, REPLACE';

  /// The second confirmation shown before a replace-mode restore. Pops
  /// `true` to proceed, `false` to cancel. [archiveHasSettings] picks the
  /// honest copy: v2 archives replace settings, v1 archives can't.
  @visibleForTesting
  static AlertDialog buildReplaceConfirmDialog(BuildContext ctx,
      {bool archiveHasSettings = true}) {
    return AlertDialog(
      backgroundColor: Theme.of(ctx).colorScheme.surface,
      title: Text(
        replaceAllTitle,
        style: AppTheme.displayFont(fontSize: 16),
      ),
      content: Text(
        archiveHasSettings ? replaceAllWarning : replaceAllWarningNoSettings,
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
            replaceAllConfirmLabel,
            style: AppTheme.monoFont(fontSize: 12, color: Colors.red),
          ),
        ),
      ],
    );
  }

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
    // The metadata snapshot vault (BACKUP_RETENTION_SPEC in PT's plaintext
    // idiom): app-documents/metadata_vault on Android, OPFS on web.
    _backupService = BackupService(
      widget.storageService,
      vault: BackupVault(
        FileVaultStore(createPlatformVaultFileApi(dirName: 'metadata_vault')),
        appId: 'punctum',
        extension: 'json',
      ),
    );
    _loadEstimatedSize();
  }

  Future<void> _loadEstimatedSize() async {
    final size = await _backupService.getBackupSize(
        includeMontages: widget.storageService.getIncludeMontagesInBackup());
    if (mounted) {
      setState(() => _estimatedSize = size);
    }
  }

  Future<void> _restoreSnapshot(String id) async {
    setState(() {
      _isRestoring = true;
      _progress = 0;
      _statusMessage = 'Restoring snapshot...';
    });
    try {
      await _backupService.restoreMetadataSnapshot(id, (progress) {
        if (mounted) setState(() => _progress = progress);
      });
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusMessage = null;
        });
        _showSuccess('Snapshot restored');
        _loadEstimatedSize();
      }
    } on PreRestoreSnapshotException {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusMessage = null;
        });
        _showError("Couldn't save a safety snapshot first, so nothing was "
            'changed. Free up some space and try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusMessage = null;
        });
        _showError('Snapshot restore failed: $e');
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
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
      final info = await _backupService.createBackup(
        outputPath,
        includeMontages: widget.storageService.getIncludeMontagesInBackup(),
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
          // The count comes from re-reading the encoded bytes — the copy
          // is a verification receipt, not an assumption.
          _showSuccess('Backed up and verified — ${info.clipFileCount} '
              'clip files downloaded');
        } else {
          final fileName = outputPath.split('/').last;
          await _showBackupOptions(outputPath, fileName);
          if (mounted) {
            _showSuccess(
                'Backed up and verified — ${info.clipFileCount} clip files');
          }
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                Text(
                  _formatBytes(info.sizeBytes),
                  style: AppTheme.monoFont(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (info.faceCount > 0)
                  Text(
                    '${info.faceCount} face references',
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => BackupRestoreScreen.buildReplaceConfirmDialog(
              ctx, archiveHasSettings: info.hasSettings),
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
    } on PreRestoreSnapshotException {
      // Fail-closed: the mandatory safety snapshot couldn't be saved, so
      // the restore never started — say exactly that, calmly.
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusMessage = null;
        });
        _showError("Couldn't save a safety snapshot of your current "
            'journal, so the restore was not started. Free up some space '
            'and try again.');
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                                    .withValues(alpha: 0.5),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                  Row(
                    children: [
                      Switch(
                        value:
                            widget.storageService.getIncludeMontagesInBackup(),
                        onChanged: (v) async {
                          await widget.storageService
                              .setIncludeMontagesInBackup(v);
                          if (mounted) setState(() {});
                          _loadEstimatedSize();
                        },
                        activeThumbColor: theme.colorScheme.primary,
                      ),
                      Expanded(
                        child: Text(
                          'Include montage videos',
                          style: AppTheme.monoFont(fontSize: 12),
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
                                    .withValues(alpha: 0.5),
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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

            // PREVIOUS SNAPSHOTS — the retention spec's vault, PT-style.
            _buildSectionHeader('PREVIOUS SNAPSHOTS'),
            MetadataSnapshotsSection(
              vault: _backupService.vault,
              onRestoreSnapshot: _restoreSnapshot,
            ),

            const SizedBox(height: 24),

            // SHARE / DOWNLOAD section
            _buildSectionHeader(kIsWeb ? 'DOWNLOAD COMPILATIONS' : 'SHARE COMPILATIONS'),

            if (compilations.isEmpty)
              Text(
                'No compilations yet',
                style: AppTheme.monoFont(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                                        .withValues(alpha: 0.5),
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
