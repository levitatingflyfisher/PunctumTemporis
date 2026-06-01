import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/ffmpeg_service.dart';
import '../models/clip.dart';
import '../platform/file_storage.dart';
import '../utils/date_format_util.dart';
import '../widgets/crt_effects.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../widgets/thumbnail_image.dart';

class CompilationScreen extends StatefulWidget {
  final StorageService storageService;

  static const backgroundToastMessage = 'Compiling — results when you return.';

  static String seasonLabel(DateTime date) {
    final m = date.month;
    if (m >= 3 && m <= 5) return 'SPRING (MAR-MAY)';
    if (m >= 6 && m <= 8) return 'SUMMER (JUN-AUG)';
    if (m >= 9 && m <= 11) return 'FALL (SEP-NOV)';
    return 'WINTER (DEC-FEB)';
  }

  const CompilationScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<CompilationScreen> createState() => _CompilationScreenState();
}

class _CompilationScreenState extends State<CompilationScreen>
    with WidgetsBindingObserver {
  final _ffmpegService = FFmpegService();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _addDateOverlay = true;
  bool _isCompiling = false;
  double _progress = 0;
  String? _compiledPath;
  VideoPlayerController? _previewController;
  String? _previewBlobUrl; // web-only: revoked on dispose
  bool _isPreviewReady = false;

  // Multi-track audio support
  List<AudioSegment> _audioSegments = [];
  double _originalVolume = 0.3;

  // EXIF date toggle
  bool _useExifDates = false;

  // Location overlay toggle
  bool? _includeLocation;

  // Tag filter
  final Set<String> _selectedTags = {};
  // Location filter
  final Set<String> _selectedLocations = {};
  // Day of week filter (1=Mon..7=Sun per DateTime.weekday)
  final Set<int> _selectedWeekdays = {};

  bool get _hasActiveFilters =>
      _selectedTags.isNotEmpty ||
      _selectedLocations.isNotEmpty ||
      _selectedWeekdays.isNotEmpty;

  List<Clip> get _clipsInRange {
    if (_startDate == null || _endDate == null) return [];

    final startStr = DateFormatUtil.format(_startDate!, DateFormatOption.isoDate);
    final endStr = DateFormatUtil.format(_endDate!, DateFormatOption.isoDate);

    if (_hasActiveFilters) {
      return widget.storageService.getClipsInRangeFiltered(
        startStr,
        endStr,
        tagFilter: _selectedTags,
        locationFilter: _selectedLocations,
        weekdayFilter: _selectedWeekdays,
      );
    }
    return widget.storageService.getClipsInRange(startStr, endStr);
  }

  List<DateTime> _allDaysInRange() {
    if (_startDate == null || _endDate == null) return [];
    final days = <DateTime>[];
    var d = _startDate!;
    while (!d.isAfter(_endDate!)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    return days;
  }

  Future<void> _selectDateRange() async {
    final range = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => RetroDateRangePickerDialog(
        storageService: widget.storageService,
        initialRange: _startDate != null && _endDate != null
            ? DateTimeRange(start: _startDate!, end: _endDate!)
            : null,
      ),
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
        _compiledPath = null;
        _isPreviewReady = false;
      });
      _disposePreview();
    }
  }

  void _setQuickRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = end;
      _compiledPath = null;
      _isPreviewReady = false;
    });
    _disposePreview();
  }

  Future<void> _addAudioSegment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: kIsWeb,
    );
    if (result == null) return;

    String? audioPath;
    if (kIsWeb) {
      final bytes = result.files.single.bytes;
      if (bytes != null) {
        final ext = result.files.single.extension ?? 'mp3';
        audioPath = 'opfs://audio_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await FileStorage.writeBytes(audioPath, bytes);
      }
    } else {
      audioPath = result.files.single.path;
    }

    if (audioPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load audio file')),
        );
      }
      return;
    }

    setState(() {
      _audioSegments.add(AudioSegment(
        filePath: audioPath!,
        fileName: result.files.single.name,
      ));
    });
  }

  void _removeAudioSegment(int index) {
    setState(() {
      _audioSegments.removeAt(index);
    });
  }

  double get _compilationDuration {
    final clips = _clipsInRange;
    return clips.fold<double>(0.0, (sum, c) => sum + (c.duration ?? 1.0));
  }

  void _disposePreview() {
    _previewController?.dispose();
    _previewController = null;
    if (_previewBlobUrl != null) {
      FileStorage.revokeObjectUrl(_previewBlobUrl!);
      _previewBlobUrl = null;
    }
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

  Future<void> _compile() async {
    final clips = _clipsInRange;
    if (clips.isEmpty) {
      _showError('No clips in selected range');
      return;
    }

    setState(() {
      _isCompiling = true;
      _progress = 0;
    });

    try {
      // On web use OPFS temp paths; on native use the system temp directory
      final String tempPrefix;
      if (kIsWeb) {
        tempPrefix = 'opfs://overlay_';
      } else {
        // path_provider is only used on native — import kept in native runner
        // Use FileStorage via storage_service temp dir concept
        final base = await FileStorage.appDocDir();
        tempPrefix = '$base/overlay_';
      }
      List<String> clipPathsToConcat;

      // If date overlay enabled, process each clip first
      if (_addDateOverlay) {
        clipPathsToConcat = [];
        final formatOption =
            DateFormatUtil.fromKey(widget.storageService.getDateFormat());

        final showLocation = _includeLocation ??
            widget.storageService.getIncludeLocationOverlay();

        for (var i = 0; i < clips.length; i++) {
          final clip = clips[i];
          final overlayDateStr = (_useExifDates && clip.exifDate != null)
              ? clip.exifDate!
              : clip.date;
          final overlayDate = DateTime.parse(overlayDateStr);
          final dateText = DateFormatUtil.format(overlayDate, formatOption);
          final locationText = showLocation ? clip.locationLabel : null;
          final tempPath = '${tempPrefix}$i.mp4';

          if (!mounted) return;
          setState(() => _progress = (i / clips.length) * 0.5);

          final result = await _ffmpegService.addDateOverlay(
            clip.filePath,
            tempPath,
            dateText,
            locationText: locationText,
          );

          if (result != null) {
            clipPathsToConcat.add(result);
          } else {
            // Fallback to original if overlay fails
            clipPathsToConcat.add(clip.filePath);
          }
        }
      } else {
        clipPathsToConcat = clips.map((c) => c.filePath).toList();
      }

      // Generate output path with date range name
      final outputPath = widget.storageService.getCompilationPath(
        DateFormatUtil.format(_startDate!, DateFormatOption.isoDate),
        DateFormatUtil.format(_endDate!, DateFormatOption.isoDate),
      );

      final result = await _ffmpegService.concatenateClips(
        clipPathsToConcat,
        outputPath,
        onProgress: (progress) {
          if (mounted) {
            setState(() =>
                _progress = _addDateOverlay ? 0.5 + progress * 0.5 : progress);
          }
        },
      );

      // Clean up temp overlay files
      if (_addDateOverlay) {
        for (final path in clipPathsToConcat) {
          if (path.startsWith(tempPrefix)) {
            await FileStorage.deleteFile(path).catchError((_) {});
          }
        }
      }

      if (result == null) {
        if (!mounted) return;
        _showError('Compilation failed');
        setState(() => _isCompiling = false);
        return;
      }

      // Add audio tracks if any
      if (_audioSegments.isNotEmpty) {
        if (!mounted) return;
        setState(() => _progress = 0.9);
        final musicOutputPath =
            '${outputPath.replaceAll('.mp4', '')}_music.mp4';
        if (_audioSegments.length == 1 &&
            _audioSegments.first.startTimeInCompilation == 0 &&
            _audioSegments.first.audioOffset == 0) {
          // Simple single-track case — use existing method
          final musicResult = await _ffmpegService.addBackgroundMusic(
            outputPath,
            _audioSegments.first.filePath,
            musicOutputPath,
            musicVolume: _audioSegments.first.volume,
            originalVolume: _originalVolume,
          );
          if (musicResult != null) {
            await FileStorage.copyFile(musicOutputPath, outputPath);
            await FileStorage.deleteFile(musicOutputPath);
          }
        } else {
          // Multi-track case
          final musicResult = await _ffmpegService.addMultipleAudioTracks(
            outputPath,
            _audioSegments,
            musicOutputPath,
            originalVolume: _originalVolume,
          );
          if (musicResult != null) {
            await FileStorage.copyFile(musicOutputPath, outputPath);
            await FileStorage.deleteFile(musicOutputPath);
          }
        }
      }

      // Create compilation record with readable title
      final compilation = Compilation(
        id: widget.storageService.generateId(),
        title:
            '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
        filePath: outputPath,
        clipIds: clips.map((c) => c.id).toList(),
        createdAt: DateTime.now(),
        startDate: DateFormatUtil.format(_startDate!, DateFormatOption.isoDate),
        endDate: DateFormatUtil.format(_endDate!, DateFormatOption.isoDate),
        duration:
            clips.fold<double>(0.0, (sum, c) => sum + (c.duration ?? 1.0)),
      );

      await widget.storageService.addCompilation(compilation);

      if (!mounted) return;
      setState(() {
        _isCompiling = false;
        _compiledPath = outputPath;
      });

      // Initialize preview after state update
      await _initializePreview(outputPath);
    } catch (e) {
      if (!mounted) return;
      _showError('Compilation error: $e');
      setState(() => _isCompiling = false);
    }
  }

  Future<void> _initializePreview(String path) async {
    _disposePreview();

    if (!await FileStorage.exists(path)) {
      _showError('Video file not found');
      return;
    }

    try {
      if (kIsWeb) {
        final bytes = await FileStorage.readBytes(path);
        if (bytes == null) {
          _showError('Video file not found');
          return;
        }
        _previewBlobUrl = FileStorage.createObjectUrl(bytes, 'video/mp4');
        _previewController =
            VideoPlayerController.networkUrl(Uri.parse(_previewBlobUrl!));
      } else {
        _previewController =
            VideoPlayerController.networkUrl(Uri.file(path));
      }
      await _previewController!.initialize();
      await _previewController!.setLooping(true);

      if (mounted) {
        setState(() => _isPreviewReady = true);
      }
    } catch (e) {
      _showError('Failed to load preview: $e');
    }
  }

  void _playPreview() {
    if (_previewController == null || !_isPreviewReady) return;

    if (_previewController!.value.isPlaying) {
      _previewController!.pause();
    } else {
      _previewController!.play();
    }
    setState(() {});
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposePreview();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused && _isCompiling) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(CompilationScreen.backgroundToastMessage),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (state == AppLifecycleState.resumed && _isCompiling) {
      // Compilation may have completed while backgrounded — refresh UI
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clips = _clipsInRange;

    return PopScope(
      canPop: !_isCompiling,
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
            'COMPILE',
          style: AppTheme.pixelFont(fontSize: 12),
        ),
      ),
      body: CrtOverlay(
        enabled: widget.storageService.getCrtEffects(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date range selector
              Text(
                'DATE RANGE',
                style: AppTheme.pixelFont(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _selectDateRange,
                child: RetroCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('MMM d, yyyy').format(_startDate!)} → ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                              : 'Select date range...',
                          style: AppTheme.displayFont(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
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

              const SizedBox(height: 16),

              // Quick compile preset buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickRangeButton(
                    label: 'THIS WEEK',
                    onTap: () {
                      final r = DateRangePresets.thisWeek();
                      _setQuickRange(r.start, r.end);
                    },
                  ),
                  _QuickRangeButton(
                    label: 'THIS MONTH',
                    onTap: () {
                      final now = DateTime.now();
                      _setQuickRange(DateTime(now.year, now.month, 1), now);
                    },
                  ),
                  _QuickRangeButton(
                    label: 'LAST 30 DAYS',
                    onTap: () {
                      final now = DateTime.now();
                      _setQuickRange(
                          now.subtract(const Duration(days: 30)), now);
                    },
                  ),
                  _QuickRangeButton(
                    label: CompilationScreen.seasonLabel(DateTime.now()),
                    onTap: () {
                      final r = DateRangePresets.thisSeason();
                      _setQuickRange(r.start, r.end);
                    },
                  ),
                  _QuickRangeButton(
                    label: 'THIS YEAR',
                    onTap: () {
                      final now = DateTime.now();
                      _setQuickRange(DateTime(now.year, 1, 1), now);
                    },
                  ),
                  _QuickRangeButton(
                    label: 'LAST MONTH',
                    onTap: () {
                      final r = DateRangePresets.lastMonth();
                      _setQuickRange(r.start, r.end);
                    },
                  ),
                  _QuickRangeButton(
                    label: 'LAST YEAR',
                    onTap: () {
                      final r = DateRangePresets.lastYear();
                      _setQuickRange(r.start, r.end);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Clips info
              if (_startDate != null && _endDate != null) ...[
                Row(
                  children: [
                    Text(
                      'CLIPS FOUND',
                      style: AppTheme.pixelFont(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${clips.length} / ${_allDaysInRange().length} days',
                      style: AppTheme.displayFont(
                        fontSize: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Tag filter chips
                if (widget.storageService.allTagsWithPinned.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final sortedTags =
                        widget.storageService.allTagsWithPinned.toList()
                          ..sort();
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...sortedTags.map((tag) {
                          final selected = _selectedTags.contains(tag);
                          final pinned =
                              widget.storageService.pinnedTags.contains(tag);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selectedTags.remove(tag);
                                } else {
                                  _selectedTags.add(tag);
                                }
                              });
                            },
                            onLongPress: () =>
                                _showPinMenu(context, tag: tag),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
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
                                  fontSize: 12,
                                  color: selected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Location filter chips
                if (widget.storageService.allLocationsWithPinned.isNotEmpty) ...[
                  Text(
                    'LOCATIONS',
                    style: AppTheme.pixelFont(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final sortedLocations =
                        widget.storageService.allLocationsWithPinned.toList()
                          ..sort();
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sortedLocations.map((loc) {
                        final selected = _selectedLocations.contains(loc);
                        final pinned =
                            widget.storageService.pinnedLocations.contains(loc);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedLocations.remove(loc);
                              } else {
                                _selectedLocations.add(loc);
                              }
                            });
                          },
                          onLongPress: () =>
                              _showPinMenu(context, location: loc),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
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
                                Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: selected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  loc,
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
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Day of week filter
                Text(
                  'DAY OF WEEK',
                  style: AppTheme.pixelFont(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in {
                      1: 'MON',
                      2: 'TUE',
                      3: 'WED',
                      4: 'THU',
                      5: 'FRI',
                      6: 'SAT',
                      7: 'SUN'
                    }.entries)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedWeekdays.contains(entry.key)) {
                              _selectedWeekdays.remove(entry.key);
                            } else {
                              _selectedWeekdays.add(entry.key);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _selectedWeekdays.contains(entry.key)
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            border:
                                Border.all(color: theme.colorScheme.primary),
                          ),
                          child: Text(
                            entry.value,
                            style: AppTheme.monoFont(
                              fontSize: 12,
                              color: _selectedWeekdays.contains(entry.key)
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Clear all filters
                if (_hasActiveFilters)
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedTags.clear();
                      _selectedLocations.clear();
                      _selectedWeekdays.clear();
                    }),
                    child: Text(
                      'CLEAR ALL FILTERS',
                      style: AppTheme.monoFont(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                if (clips.isEmpty)
                  Text(
                    'No clips in this range',
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  )
                else ...[
                  // Day grid with thumbnails
                  _CompilationDayGrid(
                    days: _allDaysInRange(),
                    clips: widget.storageService.clips,
                    formatDate: (date) => DateFormatUtil.format(date, DateFormatOption.isoDate),
                  ),

                  const SizedBox(height: 16),

                  // Date overlay option
                  Row(
                    children: [
                      Switch(
                        value: _addDateOverlay,
                        onChanged: (v) => setState(() => _addDateOverlay = v),
                        activeColor: theme.colorScheme.primary,
                      ),
                      Text(
                        'Add date overlay to clips',
                        style: AppTheme.monoFont(fontSize: 14),
                      ),
                    ],
                  ),

                  // EXIF date toggle (only when overlay enabled and mismatches exist)
                  if (_addDateOverlay && clips.any((c) => c.hasDateMismatch))
                    Row(
                      children: [
                        Switch(
                          value: _useExifDates,
                          onChanged: (v) => setState(() => _useExifDates = v),
                          activeColor: Colors.amber,
                        ),
                        Expanded(
                          child: Text(
                            'Use original capture dates',
                            style: AppTheme.monoFont(fontSize: 14),
                          ),
                        ),
                      ],
                    ),

                  // Location overlay toggle (only when overlay enabled and any clips have location)
                  if (_addDateOverlay &&
                      clips.any((c) => c.locationLabel != null))
                    Row(
                      children: [
                        Switch(
                          value: _includeLocation ??
                              widget.storageService.getIncludeLocationOverlay(),
                          onChanged: (v) =>
                              setState(() => _includeLocation = v),
                          activeColor: theme.colorScheme.primary,
                        ),
                        Expanded(
                          child: Text(
                            'Include location in overlay',
                            style: AppTheme.monoFont(fontSize: 14),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Audio tracks
                  Text(
                    'AUDIO',
                    style: AppTheme.pixelFont(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_audioSegments.isNotEmpty) ...[
                    // Original audio volume
                    Row(
                      children: [
                        Text(
                          'ORIGINAL',
                          style: AppTheme.monoFont(
                              fontSize: 12, color: theme.colorScheme.primary),
                        ),
                        Expanded(
                          child: Slider(
                            value: _originalVolume,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) =>
                                setState(() => _originalVolume = v),
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${(_originalVolume * 100).toInt()}%',
                          style: AppTheme.monoFont(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Audio segment cards
                    ...List.generate(_audioSegments.length, (i) {
                      final seg = _audioSegments[i];
                      final compDur = _compilationDuration;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RetroCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.music_note,
                                      color: theme.colorScheme.primary,
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      seg.fileName,
                                      style: AppTheme.monoFont(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close,
                                        size: 18,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.5)),
                                    onPressed: () => _removeAudioSegment(i),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Volume
                              Row(
                                children: [
                                  Text('VOL',
                                      style: AppTheme.monoFont(
                                          fontSize: 11,
                                          color: theme.colorScheme.primary)),
                                  Expanded(
                                    child: Slider(
                                      value: seg.volume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (v) => setState(() {
                                        _audioSegments[i] =
                                            seg.copyWith(volume: v);
                                      }),
                                      activeColor: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text('${(seg.volume * 100).toInt()}%',
                                      style: AppTheme.monoFont(fontSize: 10)),
                                ],
                              ),
                              // Start time in compilation
                              Row(
                                children: [
                                  Text('START AT',
                                      style: AppTheme.monoFont(
                                          fontSize: 11,
                                          color: theme.colorScheme.primary)),
                                  Expanded(
                                    child: Slider(
                                      value: seg.startTimeInCompilation
                                          .clamp(0, compDur),
                                      min: 0,
                                      max: compDur > 0 ? compDur : 1,
                                      onChanged: (v) => setState(() {
                                        _audioSegments[i] = seg.copyWith(
                                            startTimeInCompilation: v);
                                      }),
                                      activeColor: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                      '${seg.startTimeInCompilation.toStringAsFixed(1)}s',
                                      style: AppTheme.monoFont(fontSize: 10)),
                                ],
                              ),
                              // Audio offset (start position in the song)
                              Row(
                                children: [
                                  Text('FROM',
                                      style: AppTheme.monoFont(
                                          fontSize: 11,
                                          color: theme.colorScheme.primary)),
                                  Expanded(
                                    child: Slider(
                                      value: seg.audioOffset,
                                      min: 0,
                                      max: 300, // 5 min max offset
                                      onChanged: (v) => setState(() {
                                        _audioSegments[i] =
                                            seg.copyWith(audioOffset: v);
                                      }),
                                      activeColor: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text('${seg.audioOffset.toStringAsFixed(1)}s',
                                      style: AppTheme.monoFont(fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  GestureDetector(
                    onTap: _addAudioSegment,
                    child: RetroCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Add music...',
                            style: AppTheme.monoFont(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Compile button
                  Center(
                    child: RetroButton(
                      onPressed:
                          _isCompiling || clips.isEmpty ? null : _compile,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.movie_creation, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'COMPILE VIDEO',
                            style: AppTheme.monoFont(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Progress
                  if (_isCompiling) ...[
                    const SizedBox(height: 24),
                    Text(
                      _addDateOverlay && _progress < 0.5
                          ? 'ADDING DATE OVERLAYS...'
                          : 'COMPILING...',
                      style: AppTheme.pixelFont(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RetroProgressBar(
                      value: _progress,
                      height: 16,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: AppTheme.monoFont(fontSize: 12),
                    ),
                  ],
                ],
              ],

              // Preview (rendered independently so opening existing compilations works)
              if (_compiledPath != null &&
                  _isPreviewReady &&
                  _previewController != null) ...[
                const SizedBox(height: 32),
                Text(
                  'PREVIEW',
                  style: AppTheme.pixelFont(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _playPreview,
                  child: AspectRatio(
                    aspectRatio:
                        _previewController!.value.aspectRatio.clamp(0.5, 2.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_previewController!),
                        if (!_previewController!.value.isPlaying)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Saved: ${_compiledPath!.split('/').last}',
                        style: AppTheme.monoFont(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.share,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      onPressed: () async {
                        if (kIsWeb) {
                          final bytes = await FileStorage.readBytes(_compiledPath!);
                          if (bytes != null) {
                            final fileName = 'compilation_${DateTime.now().millisecondsSinceEpoch}.mp4';
                            await FileStorage.downloadFile(bytes, fileName, 'video/mp4');
                          }
                        } else {
                          await Share.shareXFiles([XFile(_compiledPath!)]);
                        }
                      },
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Previous compilations
              Text(
                'PREVIOUS COMPILATIONS',
                style: AppTheme.pixelFont(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.storageService.compilations.reversed
                  .map((c) => _CompilationTile(
                        compilation: c,
                        onTap: () => _openCompilation(c),
                        onDelete: () => _deleteCompilation(c),
                      )),
              if (widget.storageService.compilations.isEmpty)
                Text(
                  'No compilations yet',
                  style: AppTheme.monoFont(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _openCompilation(Compilation compilation) async {
    setState(() {
      _isPreviewReady = false;
      _compiledPath = compilation.filePath;
      // Populate date range from compilation model so preview renders
      if (compilation.startDate != null) {
        _startDate = DateTime.parse(compilation.startDate!);
      }
      if (compilation.endDate != null) {
        _endDate = DateTime.parse(compilation.endDate!);
      }
    });
    await _initializePreview(compilation.filePath);

    // Auto-play when opening existing compilation
    if (_isPreviewReady && _previewController != null) {
      _previewController!.play();
      setState(() {});
    }
  }

  Future<void> _deleteCompilation(Compilation compilation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'DELETE COMPILATION?',
          style: AppTheme.displayFont(fontSize: 18),
        ),
        content: Text(
          'This will permanently delete "${compilation.title}".',
          style: AppTheme.monoFont(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: AppTheme.monoFont(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DELETE',
              style: AppTheme.monoFont(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageService.deleteCompilation(compilation.id);
      setState(() {});
    }
  }
}

class _QuickRangeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickRangeButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: AppTheme.monoFont(
            fontSize: 12,
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _CompilationDayGrid extends StatelessWidget {
  final List<DateTime> days;
  final Map<String, List<Clip>> clips;
  final String Function(DateTime) formatDate;

  const _CompilationDayGrid({
    required this.days,
    required this.clips,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final dateStr = formatDate(day);
        final clipList = clips[dateStr];
        final firstClip =
            (clipList != null && clipList.isNotEmpty) ? clipList.first : null;
        final clipCount = clipList?.length ?? 0;
        return _CompilationDayCell(
            day: day, clip: firstClip, clipCount: clipCount);
      },
    );
  }
}

class _CompilationDayCell extends StatelessWidget {
  final DateTime day;
  final Clip? clip;
  final int clipCount;

  const _CompilationDayCell(
      {required this.day, required this.clip, this.clipCount = 0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasClip = clip != null;

    if (hasClip && clip!.thumbnailPath != null) {
      return Stack(
        children: [
          Positioned.fill(child: ThumbnailImage(path: clip!.thumbnailPath!)),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 2),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: Colors.black.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  day.day.toString(),
                  textAlign: TextAlign.center,
                  style: AppTheme.monoFont(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ),
          if (clipCount > 1)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                padding: const EdgeInsets.all(2),
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
      );
    }

    if (hasClip) {
      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            child: Center(
              child: Text(
                day.day.toString(),
                style: AppTheme.monoFont(
                  fontSize: 12,
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (clipCount > 1)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  clipCount.toString(),
                  style: AppTheme.monoFont(
                    fontSize: 11,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          day.day.toString(),
          style: AppTheme.monoFont(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.25),
          ),
        ),
      ),
    );
  }
}

class _CompilationTile extends StatelessWidget {
  final Compilation compilation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CompilationTile({
    required this.compilation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: RetroCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.movie,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compilation.title,
                      style: AppTheme.displayFont(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${compilation.clipIds.length} clips • ${DateFormat('MMM d').format(compilation.createdAt)}',
                      style: AppTheme.monoFont(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
