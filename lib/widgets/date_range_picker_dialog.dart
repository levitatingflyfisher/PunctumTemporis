import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../utils/date_format_util.dart';
import 'thumbnail_image.dart';

class DateRangePresets {
  static DateTimeRange thisWeek() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  static DateTimeRange thisSeason() {
    final now = DateTime.now();
    final m = now.month;
    int startMonth;
    int startYear = now.year;
    if (m >= 3 && m <= 5) {
      startMonth = 3;
    } else if (m >= 6 && m <= 8) {
      startMonth = 6;
    } else if (m >= 9 && m <= 11) {
      startMonth = 9;
    } else {
      startMonth = 12;
      if (m < 12) startYear = now.year - 1;
    }
    return DateTimeRange(
      start: DateTime(startYear, startMonth, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  static DateTimeRange thisMonth() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  static DateTimeRange lastWeek() {
    final now = DateTime.now();
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final start = DateTime(lastMonday.year, lastMonday.month, lastMonday.day);
    final end = start.add(const Duration(days: 6)); // Sunday
    return DateTimeRange(start: start, end: end);
  }

  static DateTimeRange lastMonth() {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month - 1, 1);
    return DateTimeRange(
      start: first,
      end: DateTime(now.year, now.month, 0),
    );
  }

  static DateTimeRange thisYear() {
    final year = DateTime.now().year;
    return DateTimeRange(
      start: DateTime(year, 1, 1),
      end: DateTime(year, 12, 31),
    );
  }

  static DateTimeRange lastYear() {
    final year = DateTime.now().year - 1;
    return DateTimeRange(
      start: DateTime(year, 1, 1),
      end: DateTime(year, 12, 31),
    );
  }

  static DateTimeRange allTime(StorageService storageService) {
    DateTime earliest = DateTime.now();
    for (final dateStr in storageService.clips.keys) {
      try {
        final d = DateTime.parse(dateStr);
        if (d.isBefore(earliest)) earliest = d;
      } catch (_) {}
    }
    return DateTimeRange(start: earliest, end: DateTime.now());
  }
}

class RetroDateRangePickerDialog extends StatefulWidget {
  final StorageService storageService;
  final DateTimeRange? initialRange;

  const RetroDateRangePickerDialog({
    super.key,
    required this.storageService,
    this.initialRange,
  });

  @override
  State<RetroDateRangePickerDialog> createState() =>
      _RetroDateRangePickerDialogState();
}

class _RetroDateRangePickerDialogState
    extends State<RetroDateRangePickerDialog> {
  late DateTime _displayedMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _selectingEnd = false;
  bool _showingMonthYearPicker = false;
  late int _pickerYear;
  late final DateTimeRange _allTimeRange =
      DateRangePresets.allTime(widget.storageService);

  @override
  void initState() {
    super.initState();
    if (widget.initialRange != null) {
      _startDate = widget.initialRange!.start;
      _endDate = widget.initialRange!.end;
      _selectingEnd = true;
      _displayedMonth = DateTime(_startDate!.year, _startDate!.month, 1);
    } else {
      _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    }
    _pickerYear = _displayedMonth.year;
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  void _onDayTapped(DateTime date) {
    setState(() {
      if (!_selectingEnd || _startDate == null) {
        // First tap or re-selecting
        _startDate = date;
        _endDate = null;
        _selectingEnd = true;
      } else {
        // Second tap — set end, auto-swap if needed
        if (date.isBefore(_startDate!)) {
          _endDate = _startDate;
          _startDate = date;
        } else {
          _endDate = date;
        }
        _selectingEnd = false;
      }
    });
  }

  bool _isInRange(DateTime date) {
    if (_startDate == null || _endDate == null) return false;
    return !date.isBefore(_startDate!) && !date.isAfter(_endDate!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    // Calendar math
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDay =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final startingWeekday = firstDay.weekday % 7; // Sunday = 0
    final daysInMonth = lastDay.day;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'SELECT DATE RANGE',
                    style: AppTheme.pixelFont(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Preset chips
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.75, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _presetChip('THIS WEEK', DateRangePresets.thisWeek()),
                    _presetChip('LAST WEEK', DateRangePresets.lastWeek()),
                    _presetChip('THIS MONTH', DateRangePresets.thisMonth()),
                    _presetChip('LAST MONTH', DateRangePresets.lastMonth()),
                    _presetChip('THIS YEAR', DateRangePresets.thisYear()),
                    _presetChip('LAST YEAR', DateRangePresets.lastYear()),
                    _presetChip('ALL TIME', _allTimeRange),
                  ],
                ),
              ),
            ),

            // Month navigator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousMonth,
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _showingMonthYearPicker = !_showingMonthYearPicker;
                      _pickerYear = _displayedMonth.year;
                    }),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('MMMM')
                              .format(_displayedMonth)
                              .toUpperCase(),
                          style: AppTheme.displayFont(
                            fontSize: 22,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _displayedMonth.year.toString(),
                          style: AppTheme.monoFont(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),

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
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 4),

            // Day grid or month/year picker
            if (_showingMonthYearPicker)
              _buildMonthYearPicker(theme)
            else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Leading empty cells before first day of month
                  for (var i = 0; i < startingWeekday; i++) const SizedBox(),

                  // Day cells for this month
                  for (var day = 1; day <= daysInMonth; day++)
                    _buildDayCell(
                      DateTime(
                          _displayedMonth.year, _displayedMonth.month, day),
                      today,
                      theme,
                    ),

                  // Trailing overflow cells to always fill 6 rows
                  for (var i = startingWeekday + daysInMonth; i < 42; i++)
                    _buildOverflowCell(i - startingWeekday - daysInMonth + 1, theme),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Selected range display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('MMM d').format(_startDate!)} \u2192 ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                        : _startDate != null
                            ? '${DateFormat('MMM d, yyyy').format(_startDate!)} \u2192 ...'
                            : 'Tap a day to start',
                    style: AppTheme.displayFont(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            'CANCEL',
                            style: AppTheme.monoFont(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _startDate != null && _endDate != null
                            ? () {
                                Navigator.pop(
                                  context,
                                  DateTimeRange(
                                      start: _startDate!, end: _endDate!),
                                );
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _startDate != null && _endDate != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            'CONFIRM',
                            style: AppTheme.monoFont(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _startDate != null && _endDate != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, DateTimeRange range) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.pop(context, range),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: AppTheme.monoFont(fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildMonthYearPicker(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Year stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _pickerYear--),
              ),
              Text(
                _pickerYear.toString(),
                style: AppTheme.displayFont(fontSize: 20),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _pickerYear++),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 3×4 month grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            children: List.generate(12, (i) {
              final month = DateTime(_pickerYear, i + 1);
              final isCurrentDisplay = month.year == _displayedMonth.year &&
                  month.month == _displayedMonth.month;
              return GestureDetector(
                onTap: () => setState(() {
                  _displayedMonth = month;
                  _showingMonthYearPicker = false;
                }),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isCurrentDisplay
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('MMM').format(month).toUpperCase(),
                      style: AppTheme.monoFont(
                        fontSize: 11,
                        color: isCurrentDisplay
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowCell(int day, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(1),
      child: Center(
        child: Text(
          day.toString(),
          style: AppTheme.monoFont(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DateTime today, ThemeData theme) {
    final dateStr = DateFormatUtil.format(date, DateFormatOption.isoDate);
    final clip = widget.storageService.getFirstClipForDate(dateStr);
    final hasClip = clip != null;
    final isFuture = date.isAfter(today);
    final inRange = _isInRange(date);
    final isStart = _startDate != null &&
        date.year == _startDate!.year &&
        date.month == _startDate!.month &&
        date.day == _startDate!.day;
    final isEnd = _endDate != null &&
        date.year == _endDate!.year &&
        date.month == _endDate!.month &&
        date.day == _endDate!.day;

    final hasThumbnailPath = hasClip && clip.thumbnailPath != null;

    return GestureDetector(
      onTap: isFuture ? null : () => _onDayTapped(date),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: inRange
              ? theme.colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
          border: Border.all(
            color: isStart || isEnd
                ? theme.colorScheme.primary
                : hasClip
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withOpacity(0.1),
            width: isStart || isEnd
                ? 2
                : hasClip
                    ? 2
                    : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail background via ThumbnailImage (platform-transparent)
            if (hasThumbnailPath)
              ThumbnailImage(
                path: clip!.thumbnailPath!,
                fit: BoxFit.cover,
              ),
            // Range tint overlay on top of thumbnail
            if (hasThumbnailPath && inRange)
              Container(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            Center(
              child: hasThumbnailPath
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 1),
                      color: Colors.black.withOpacity(0.6),
                      child: Text(
                        date.day.toString(),
                        style: AppTheme.monoFont(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: isStart || isEnd
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    )
                  : Text(
                      date.day.toString(),
                      style: AppTheme.monoFont(
                        fontSize: 11,
                        color: isFuture
                            ? theme.colorScheme.onSurface.withOpacity(0.15)
                            : hasClip
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: isStart || isEnd
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
            ),
            // EXIF mismatch indicator
            if (hasClip && clip.hasDateMismatch)
              Positioned(
                top: 1,
                right: 1,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
