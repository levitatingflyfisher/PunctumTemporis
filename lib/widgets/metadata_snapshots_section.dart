import 'package:flutter/material.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart'
    show BackupVault, VaultEntry, VaultLabel, formatBackupAge;

import '../theme/app_theme.dart';
import '../widgets/crt_effects.dart';

/// The "Previous snapshots" list — PT's face of the retention spec's
/// snapshot vault. Each entry is a plaintext copy of metadata.json (the
/// journal index): the automatic safety net taken before every restore,
/// restorable in place because clip files are never deleted by a restore.
class MetadataSnapshotsSection extends StatefulWidget {
  const MetadataSnapshotsSection({
    super.key,
    required this.vault,
    required this.onRestoreSnapshot,
  });

  final BackupVault vault;

  /// Called with the snapshot id after the user confirms; the owner runs
  /// BackupService.restoreMetadataSnapshot and reports the outcome.
  final Future<void> Function(String id) onRestoreSnapshot;

  @override
  State<MetadataSnapshotsSection> createState() =>
      _MetadataSnapshotsSectionState();
}

class _MetadataSnapshotsSectionState extends State<MetadataSnapshotsSection> {
  late Future<List<VaultEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.vault.list();
  }

  void _refresh() {
    final next = widget.vault.list();
    setState(() {
      _entries = next;
    });
  }

  String _labelText(VaultLabel label) => switch (label) {
        VaultLabel.preRestore => 'Safety snapshot',
        VaultLabel.manual => 'Manual snapshot',
        VaultLabel.freshness => 'Automatic snapshot',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<VaultEntry>>(
      future: _entries,
      builder: (context, snapshot) {
        final entries = snapshot.data;
        if (entries == null) return const SizedBox.shrink();
        if (entries.isEmpty) {
          return Text(
            'No snapshots yet — one is saved automatically before every '
            'restore.',
            style: AppTheme.monoFont(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          );
        }
        return Column(
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RetroCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.history,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _labelText(entry.label),
                              style: AppTheme.displayFont(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              formatBackupAge(
                                  entry.createdAt, DateTime.now()),
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
                        icon: Icon(Icons.settings_backup_restore,
                            color: theme.colorScheme.primary, size: 20),
                        tooltip: 'Restore this snapshot',
                        onPressed: () => _confirmRestore(context, entry),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 20),
                        tooltip: 'Delete snapshot',
                        onPressed: () => _confirmDelete(context, entry),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRestore(BuildContext context, VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Restore this snapshot?'),
        content: Text(
          'Rolls your journal index and settings back to this snapshot '
          '(${formatBackupAge(entry.createdAt, DateTime.now())}). Video '
          'files are not touched. A snapshot of the current state is saved '
          'first, so you can change your mind again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onRestoreSnapshot(entry.id);
    _refresh();
  }

  Future<void> _confirmDelete(BuildContext context, VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete snapshot?'),
        content: const Text(
            'This removes the snapshot from this device. Backup ZIPs you '
            'exported elsewhere are not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.vault.delete(entry.id);
    _refresh();
  }
}
