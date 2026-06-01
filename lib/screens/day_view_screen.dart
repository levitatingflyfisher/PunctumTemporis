import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../utils/date_format_util.dart';
import '../models/clip.dart' as clip_model;
import '../widgets/crt_effects.dart';
import '../widgets/thumbnail_image.dart';
import 'clip_preview_screen.dart';
import 'video_capture_screen.dart';
import 'photo_capture_screen.dart';
import 'gallery_import_screen.dart';

class DayViewScreen extends StatefulWidget {
  final StorageService storageService;
  final DateTime initialDate;
  final String? initialClipId;
  final VoidCallback onDelete;

  const DayViewScreen({
    super.key,
    required this.storageService,
    required this.initialDate,
    this.initialClipId,
    required this.onDelete,
  });

  @override
  State<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends State<DayViewScreen> {
  late PageController _pageController;
  late DateTime _currentDate;
  late DateTime _originDate;
  DateTime get _today => DateTime.now();

  // Range: 1 year back from today (or earliest clip, whichever is earlier)
  late DateTime _startDate;
  late DateTime _endDate;

  // Optimistic reorder state: keyed by date string so PageView adjacent pages
  // each get their own stable list after a drag.
  final Map<String, List<clip_model.Clip>> _orderedClips = {};


  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate;
    _originDate = widget.initialDate;

    // Calculate bounds
    _endDate = DateTime(_today.year, _today.month, _today.day);
    final oneYearBack = DateTime(_today.year - 1, _today.month, _today.day);

    // Find earliest clip date
    DateTime earliest = oneYearBack;
    for (final dateStr in widget.storageService.clips.keys) {
      try {
        final d = DateTime.parse(dateStr);
        if (d.isBefore(earliest)) earliest = d;
      } catch (_) {}
    }
    _startDate = earliest;

    final initialPage = _dateToPage(widget.initialDate);
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _totalPages {
    return _endDate.difference(_startDate).inDays + 1;
  }

  int _dateToPage(DateTime date) {
    final clamped = date.isAfter(_endDate)
        ? _endDate
        : (date.isBefore(_startDate) ? _startDate : date);
    return clamped.difference(_startDate).inDays;
  }

  DateTime _pageToDate(int page) {
    return _startDate.add(Duration(days: page));
  }

  void _showCaptureOptions(DateTime date) {
    final dateStr = DateFormatUtil.format(date, DateFormatOption.isoDate);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.isModern ? 16 : 0),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CAPTURE FOR ${DateFormat('MMM d, yyyy').format(date).toUpperCase()}',
              style: AppTheme.pixelFont(
                fontSize: 11,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            _CaptureOption(
              icon: Icons.videocam,
              label: 'Record Video',
              subtitle: 'Tap and hold to record',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoCaptureScreen(
                      storageService: widget.storageService,
                      date: dateStr,
                    ),
                  ),
                ).then((_) {
                  _orderedClips.remove(dateStr);
                  setState(() {});
                });
              },
            ),
            const SizedBox(height: 12),
            _CaptureOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              subtitle: 'Still image as a clip',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoCaptureScreen(
                      storageService: widget.storageService,
                      date: dateStr,
                    ),
                  ),
                ).then((_) {
                  _orderedClips.remove(dateStr);
                  setState(() {});
                });
              },
            ),
            const SizedBox(height: 12),
            _CaptureOption(
              icon: Icons.photo_library,
              label: 'Import from Gallery',
              subtitle: 'Pick from your photos',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GalleryImportScreen(
                      storageService: widget.storageService,
                      date: dateStr,
                    ),
                  ),
                ).then((_) {
                  _orderedClips.remove(dateStr);
                  setState(() {});
                });
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('MMM d, yyyy').format(_currentDate).toUpperCase(),
          style: AppTheme.pixelFont(fontSize: 12),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Go to today',
            onPressed: () {
              final todayPage = _dateToPage(_today);
              _pageController.animateToPage(
                todayPage,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _totalPages,
        onPageChanged: (page) {
          setState(() {
            _currentDate = _pageToDate(page);
          });
        },
        itemBuilder: (context, page) {
          final date = _pageToDate(page);
          final dateStr = DateFormatUtil.format(date, DateFormatOption.isoDate);
          final storageClips = widget.storageService.getClipsForDate(dateStr);

          // Use the optimistically-reordered list when available, otherwise
          // seed it from storage so subsequent reorders have a stable base.
          if (!_orderedClips.containsKey(dateStr)) {
            _orderedClips[dateStr] = List.from(storageClips);
          }
          final clips = _orderedClips[dateStr]!;

          if (clips.isEmpty) {
            return _buildEmptyDay(date, theme);
          }

          // Single clip: full-screen preview (unchanged)
          if (clips.length == 1) {
            return ClipPreviewScreen(
              key: ValueKey(clips.first.id),
              storageService: widget.storageService,
              clip: clips.first,
              onDelete: () {
                widget.onDelete();
                _orderedClips.remove(dateStr);
                setState(() {});
              },
              embedded: true,
            );
          }

          // Multi-clip: inline reorderable list with sequence badges
          return _buildMultiClipList(dateStr, clips, theme);
        },
      ),
    );
  }

  Widget _buildMultiClipList(
    String dateStr,
    List<clip_model.Clip> clips,
    ThemeData theme,
  ) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      // Disable default long-press drag so it doesn't compete with PageView swipe
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        setState(() {
          final item = _orderedClips[dateStr]!.removeAt(oldIndex);
          _orderedClips[dateStr]!.insert(newIndex, item);
        });
        widget.storageService
            .reorderClips(dateStr, _orderedClips[dateStr]!.map((c) => c.id).toList());
      },
      itemCount: clips.length,
      itemBuilder: (context, index) {
        final clip = clips[index];
        return InkWell(
          key: ValueKey(clip.id),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClipPreviewScreen(
                  storageService: widget.storageService,
                  clip: clip,
                  onDelete: () {
                    widget.onDelete();
                    _orderedClips.remove(dateStr);
                    setState(() {});
                    Navigator.pop(context);
                  },
                  embedded: false,
                ),
              ),
            ).then((_) => setState(() {}));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Drag handle — left edge, explicit drag initiator only
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.drag_handle,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      size: 28,
                    ),
                  ),
                ),
                // Thumbnail with sequence badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary),
                      ),
                      child: clip.thumbnailPath != null
                          ? ThumbnailImage(
                              path: clip.thumbnailPath!,
                              placeholder: Icon(Icons.videocam,
                                  color: theme.colorScheme.primary, size: 24),
                            )
                          : Icon(Icons.videocam,
                              color: theme.colorScheme.primary, size: 24),
                    ),
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        color: Colors.black.withOpacity(0.7),
                        child: Text(
                          '${index + 1}',
                          style:
                              AppTheme.monoFont(fontSize: 9, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Title + duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        clip.locationLabel ??
                            DateFormat('MMM d').format(DateTime.parse(dateStr)),
                        style: AppTheme.monoFont(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${clip.duration?.toStringAsFixed(1) ?? "1.0"}s',
                        style: AppTheme.monoFont(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                // Chevron — visual affordance for tap-to-open
                Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDay(DateTime date, ThemeData theme) {
    final isFuture = date.isAfter(_today);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFuture ? Icons.schedule : Icons.videocam_off_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            isFuture ? 'FUTURE DATE' : 'NO CLIP',
            style: AppTheme.pixelFont(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE').format(date).toUpperCase(),
            style: AppTheme.monoFont(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
          ),
          if (!isFuture) ...[
            const SizedBox(height: 24),
            RetroButton(
              onPressed: () => _showCaptureOptions(date),
              color: theme.colorScheme.primary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: theme.colorScheme.onPrimary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'CAPTURE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.monoFont(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CaptureOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _CaptureOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          borderRadius: AppTheme.isModern ? BorderRadius.circular(8) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: AppTheme.isModern ? 1 : 2,
                ),
                borderRadius:
                    AppTheme.isModern ? BorderRadius.circular(8) : null,
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.displayFont(
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTheme.monoFont(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
