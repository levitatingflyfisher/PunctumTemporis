import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../utils/date_format_util.dart';
import '../models/clip.dart' as clip_model;
import '../widgets/crt_effects.dart';
import 'video_capture_screen.dart';
import 'photo_capture_screen.dart';
import 'gallery_import_screen.dart';
import 'clip_preview_screen.dart';
import 'day_view_screen.dart';
import 'compilation_screen.dart';
import 'settings_screen.dart';
import 'year_review_screen.dart';
import '../widgets/thumbnail_image.dart';

class CalendarScreen extends StatefulWidget {
  final StorageService storageService;
  final void Function(int mode, Color accent) onThemeChanged;
  final VoidCallback? onVisualStyleChanged;

  const CalendarScreen({
    super.key,
    required this.storageService,
    required this.onThemeChanged,
    this.onVisualStyleChanged,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _currentMonth;
  DateTime get _today => DateTime.now();
  DateTime? _lastViewedDate;

  // Search/filter state
  bool _isSearchOpen = false;
  final Set<String> _filterTags = {};
  final Set<String> _filterLocations = {};
  final Set<String> _filterPeople = {};

  bool get _hasActiveFilters =>
      _filterTags.isNotEmpty ||
      _filterLocations.isNotEmpty ||
      _filterPeople.isNotEmpty;

  Set<String> get _filteredDates {
    if (!_hasActiveFilters) return widget.storageService.datesWithClips;
    final result = <String>{};
    for (final entry in widget.storageService.clips.entries) {
      for (final clip in entry.value) {
        bool matches = true;
        if (_filterTags.isNotEmpty) {
          matches = matches && clip.tags.any((t) => _filterTags.contains(t));
        }
        if (_filterLocations.isNotEmpty) {
          matches = matches &&
              clip.locationLabel != null &&
              _filterLocations.contains(clip.locationLabel);
        }
        if (_filterPeople.isNotEmpty) {
          matches = matches &&
              clip.detectedFaces.any((f) => _filterPeople.contains(f));
        }
        if (matches) {
          result.add(entry.key);
          break;
        }
      }
    }
    return result;
  }

  static const _streakMilestones = [7, 30, 50, 100, 200, 365];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(_today.year, _today.month, 1);
  }

  void _checkStreakCelebration() {
    final streak = widget.storageService.getCurrentStreak();
    final celebrated = widget.storageService.getCelebratedMilestones();

    for (final milestone in _streakMilestones) {
      if (streak >= milestone && !celebrated.contains(milestone)) {
        widget.storageService.addCelebratedMilestone(milestone);
        _showStreakCelebration(milestone);
        break;
      }
    }
  }

  void _showStreakCelebration(int days) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter:
                      _CelebrationPainter(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$days-DAY STREAK!',
                style: AppTheme.pixelFont(
                  fontSize: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _getMilestoneMessage(days),
                style: AppTheme.monoFont(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                  ),
                  child: Text(
                    'AWESOME',
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
        ),
      ),
    );
  }

  String _getMilestoneMessage(int days) {
    switch (days) {
      case 7:
        return 'One whole week! Keep going.';
      case 30:
        return 'A full month of moments captured.';
      case 50:
        return 'Fifty days strong!';
      case 100:
        return 'Triple digits! Incredible dedication.';
      case 200:
        return 'Two hundred days of memories.';
      case 365:
        return 'A FULL YEAR. You are legendary.';
      default:
        return 'Keep capturing those moments!';
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime(_today.year, _today.month, 1);
    });
  }

  void _onDayTapped(DateTime date) {
    final dateStr = DateFormatUtil.format(date, DateFormatOption.isoDate);
    final clips = widget.storageService.getClipsForDate(dateStr);

    if (clips.isNotEmpty) {
      // Has clips — show bottom sheet (even for single clip, so user can add more)
      _showClipsForDate(date, clips);
    } else if (!date.isAfter(_today)) {
      // No clips — show capture options for past/today
      _showCaptureOptions(date);
    }
  }

  void _showClipsForDate(DateTime date, List<clip_model.Clip> clips) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('MMM d, yyyy').format(date).toUpperCase()} — ${clips.length} CLIPS',
              style: AppTheme.pixelFont(
                fontSize: 11,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...clips.map((clip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      _lastViewedDate = date;
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DayViewScreen(
                            storageService: widget.storageService,
                            initialDate: date,
                            initialClipId: clip.id,
                            onDelete: () => setState(() {}),
                          ),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Thumbnail
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            child: clip.thumbnailPath != null
                                ? ThumbnailImage(
                                    path: clip.thumbnailPath!,
                                    placeholder: Icon(Icons.videocam,
                                        color: theme.colorScheme.primary,
                                        size: 24),
                                  )
                                : Icon(Icons.videocam,
                                    color: theme.colorScheme.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTypeLabel(clip.type),
                                  style: AppTheme.displayFont(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '${clip.duration?.toStringAsFixed(1) ?? "1.0"}s${clip.locationLabel != null ? " · ${clip.locationLabel}" : ""}',
                                  style: AppTheme.monoFont(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
            if (!date.isAfter(_today))
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _showCaptureOptions(date);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'ADD MORE',
                          style: AppTheme.monoFont(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(clip_model.ClipType type) {
    switch (type) {
      case clip_model.ClipType.video:
        return 'RECORDED';
      case clip_model.ClipType.photo:
        return 'PHOTO';
      case clip_model.ClipType.imported:
        return 'IMPORTED';
    }
  }

  void _showCaptureOptions(DateTime date) {
    final dateStr = DateFormatUtil.format(date, DateFormatOption.isoDate);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
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
              subtitle: '1 second clip',
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
                  setState(() {});
                  _checkStreakCelebration();
                });
              },
            ),
            const SizedBox(height: 12),
            _CaptureOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              subtitle: 'Convert to 1s video',
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
                  setState(() {});
                  _checkStreakCelebration();
                });
              },
            ),
            const SizedBox(height: 12),
            _CaptureOption(
              icon: Icons.photo_library,
              label: 'Import from Gallery',
              subtitle: 'Select existing media',
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
                  setState(() {});
                  _checkStreakCelebration();
                });
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showPinMenu(BuildContext context, {String? tag, String? location}) {
    final svc = widget.storageService;
    final isPinned = tag != null
        ? svc.pinnedTags.contains(tag)
        : svc.pinnedLocations.contains(location!);
    final label = tag ?? location!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
          title: Text(
            isPinned ? 'Unpin "$label"' : 'Pin "$label" (keep when unused)',
            style: AppTheme.monoFont(fontSize: 13),
          ),
          onTap: () async {
            Navigator.pop(ctx);
            if (tag != null) {
              isPinned ? await svc.unpinTag(tag) : await svc.pinTag(tag);
            } else {
              isPinned
                  ? await svc.unpinLocation(location!)
                  : await svc.pinLocation(location!);
            }
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme) {
    final allTags = widget.storageService.allTagsWithPinned.toList()..sort();
    final allLocations =
        widget.storageService.allLocationsWithPinned.toList()..sort();
    final allPeople = widget.storageService.knownPeopleNames;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (allTags.isNotEmpty) ...[
            Text(
              'TAGS',
              style: AppTheme.pixelFont(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allTags.map((tag) {
                final selected = _filterTags.contains(tag);
                final pinned =
                    widget.storageService.pinnedTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected)
                        _filterTags.remove(tag);
                      else
                        _filterTags.add(tag);
                    });
                  },
                  onLongPress: () =>
                      _showPinMenu(context, tag: tag),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                          color: theme.colorScheme.primary,
                          width: pinned ? 3 : 1),
                    ),
                    child: Text(
                      tag,
                      style: AppTheme.monoFont(
                        fontSize: 11,
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (allLocations.isNotEmpty) ...[
            Text(
              'LOCATIONS',
              style: AppTheme.pixelFont(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allLocations.map((loc) {
                final selected = _filterLocations.contains(loc);
                final pinned =
                    widget.storageService.pinnedLocations.contains(loc);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected)
                        _filterLocations.remove(loc);
                      else
                        _filterLocations.add(loc);
                    });
                  },
                  onLongPress: () =>
                      _showPinMenu(context, location: loc),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                          color: theme.colorScheme.primary,
                          width: pinned ? 3 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on,
                            size: 12,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          loc,
                          style: AppTheme.monoFont(
                            fontSize: 11,
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
            const SizedBox(height: 8),
          ],
          if (allPeople.isNotEmpty) ...[
            Text(
              'PEOPLE',
              style: AppTheme.pixelFont(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allPeople.map((name) {
                final selected = _filterPeople.contains(name);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected)
                        _filterPeople.remove(name);
                      else
                        _filterPeople.add(name);
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.face,
                            size: 12,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          name,
                          style: AppTheme.monoFont(
                            fontSize: 11,
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
            const SizedBox(height: 8),
          ],
          if (_hasActiveFilters)
            GestureDetector(
              onTap: () => setState(() {
                _filterTags.clear();
                _filterLocations.clear();
                _filterPeople.clear();
              }),
              child: Text(
                'CLEAR FILTERS',
                style: AppTheme.monoFont(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clips = widget.storageService.clips;

    return CrtOverlay(
      enabled: widget.storageService.getCrtEffects(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'ONE SECOND',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.pixelFont(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.tune,
                            color: _isSearchOpen
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          onPressed: () =>
                              setState(() => _isSearchOpen = !_isSearchOpen),
                          tooltip: 'Filter clips',
                        ),
                        if (_hasActiveFilters)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.bar_chart,
                          color: theme.colorScheme.primary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => YearReviewScreen(
                              storageService: widget.storageService,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Year in Review',
                    ),
                    IconButton(
                      icon: Icon(Icons.movie_creation_outlined,
                          color: theme.colorScheme.primary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompilationScreen(
                              storageService: widget.storageService,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Compile',
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_outlined,
                          color: theme.colorScheme.primary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              storageService: widget.storageService,
                              onThemeChanged: widget.onThemeChanged,
                              onVisualStyleChanged: widget.onVisualStyleChanged,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  ],
                ),
              ),

              // Month navigator — fixed above the scroll area so it's always reachable
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _previousMonth,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _goToToday,
                        child: Column(
                          children: [
                            Text(
                              DateFormat('MMMM')
                                  .format(_currentMonth)
                                  .toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTheme.displayFont(
                                fontSize: 28,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _currentMonth.year.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTheme.monoFont(
                                fontSize: 14,
                                color:
                                    theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ),

              if (_currentMonth.year != _today.year ||
                  _currentMonth.month != _today.month)
                TextButton(
                  onPressed: _goToToday,
                  child: Text(
                    '← TODAY',
                    style: AppTheme.monoFont(
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

              // Filter panel + calendar grid scroll together so both are
              // reachable on small screens even when many filter chips are open
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Search/Filter panel
                      if (_isSearchOpen) ...[
                        _buildFilterPanel(theme),
                      ],

                      const SizedBox(height: 16),

                      // Weekday headers
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                              .map((d) => SizedBox(
                                    width: 40,
                                    child: Center(
                                      child: Text(
                                        d,
                                        style: AppTheme.monoFont(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Calendar grid (shrinkWrap — outer SingleChildScrollView handles scroll)
                      _CalendarGrid(
                        month: _currentMonth,
                        today: _today,
                        clips: clips,
                        onDayTapped: _onDayTapped,
                        highlightedDates: _hasActiveFilters ? _filteredDates : null,
                        selectedDate: _lastViewedDate,
                      ),

                      // Stats footer — extra bottom padding to clear the floating CAPTURE button
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _StatItem(
                                label:
                                    _hasActiveFilters ? 'MATCHES' : 'CAPTURED',
                                value: _hasActiveFilters
                                    ? _filteredDates.length.toString()
                                    : widget.storageService.totalClips
                                        .toString(),
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: 'STREAK',
                                value: widget.storageService
                                    .getCurrentStreak()
                                    .toString(),
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: 'BEST',
                                value: widget.storageService
                                    .getLongestStreak()
                                    .toString(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // FAB for quick capture today
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            height: 48,
            child: RetroButton(
              onPressed: () => _showCaptureOptions(_today),
              color: theme.colorScheme.primary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20, color: theme.colorScheme.onPrimary),
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
          ),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final Map<String, List<clip_model.Clip>> clips;
  final void Function(DateTime) onDayTapped;
  final Set<String>? highlightedDates;
  final DateTime? selectedDate;

  const _CalendarGrid({
    required this.month,
    required this.today,
    required this.clips,
    required this.onDayTapped,
    this.highlightedDates,
    this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate grid
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startingWeekday = firstDay.weekday % 7; // Sunday = 0
    final daysInMonth = lastDay.day;

    // Build calendar cells
    final cells = <Widget>[];

    // Empty cells before first day
    for (var i = 0; i < startingWeekday; i++) {
      cells.add(const SizedBox());
    }

    // Day cells
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final clipList = clips[dateStr];
      final firstClip =
          (clipList != null && clipList.isNotEmpty) ? clipList.first : null;
      final clipCount = clipList?.length ?? 0;
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isSelected = selectedDate != null &&
          date.year == selectedDate!.year &&
          date.month == selectedDate!.month &&
          date.day == selectedDate!.day;
      final isFuture = date.isAfter(today);
      final isDimmed =
          highlightedDates != null && !highlightedDates!.contains(dateStr);

      if (isFuture) {
        cells.add(const SizedBox.shrink());
        continue;
      }

      cells.add(
        _DayCell(
          day: day,
          clip: firstClip,
          clipCount: clipCount,
          isToday: isToday,
          isSelected: isSelected,
          isDimmed: isDimmed,
          onTap: () => onDayTapped(date),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final clip_model.Clip? clip;
  final int clipCount;
  final bool isToday;
  final bool isSelected;
  final bool isDimmed;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.clip,
    required this.clipCount,
    required this.isToday,
    this.isSelected = false,
    this.isDimmed = false,
    required this.onTap,
  });

  bool get hasClip => clip != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bgColor;
    Color textColor;
    BoxBorder? border;

    if (hasClip) {
      // Show thumbnail as background if available (loaded async by ThumbnailImage)
      bgColor = clip!.thumbnailPath != null
          ? Colors.transparent
          : theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
      border = Border.all(
        color: isSelected
            ? theme.colorScheme.secondary
            : theme.colorScheme.primary,
        width: 2,
      );
    } else if (isToday) {
      bgColor = Colors.transparent;
      textColor = theme.colorScheme.primary;
      border = Border.all(color: theme.colorScheme.primary, width: 2);
    } else if (isSelected) {
      bgColor = Colors.transparent;
      textColor = theme.colorScheme.secondary;
      border = Border.all(
        color: theme.colorScheme.secondary,
        width: 2,
      );
    } else {
      bgColor = Colors.transparent;
      textColor = theme.colorScheme.onSurface.withOpacity(0.6);
    }

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDimmed ? 0.2 : 1.0,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (hasClip && clip!.thumbnailPath != null)
                Positioned.fill(
                  child: ThumbnailImage(path: clip!.thumbnailPath!),
                ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  border: border,
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: AppTheme.monoFont(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: hasClip ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              if (hasClip && clip!.hasDateMismatch)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    color: Colors.amber,
                  ),
                ),
              // Multi-clip count badge
              if (clipCount > 1)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      clipCount.toString(),
                      style: AppTheme.monoFont(
                        fontSize: 11,
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
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
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTheme.displayFont(
            fontSize: 32,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTheme.monoFont(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
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
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
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

/// Draws celebratory confetti-style dots and lines
class _CelebrationPainter extends CustomPainter {
  final Color color;

  _CelebrationPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Star burst lines
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * math.pi * 2;
      final innerR = 20.0;
      final outerR = 40.0 + rng.nextDouble() * 15;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * innerR, cy + math.sin(angle) * innerR),
        Offset(cx + math.cos(angle) * outerR, cy + math.sin(angle) * outerR),
        linePaint,
      );
    }

    // Center star
    final starPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 12, starPaint);

    // Dots scattered around
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final colors = [color, color.withOpacity(0.7), color.withOpacity(0.4)];
    for (var i = 0; i < 20; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = 30 + rng.nextDouble() * 25;
      final r = 2 + rng.nextDouble() * 3;
      dotPaint.color = colors[rng.nextInt(colors.length)];
      canvas.drawCircle(
        Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist),
        r,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) =>
      oldDelegate.color != color;
}
