import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../widgets/crt_effects.dart';
import '../widgets/thumbnail_image.dart';

class YearReviewScreen extends StatefulWidget {
  final StorageService storageService;

  const YearReviewScreen({super.key, required this.storageService});

  @override
  State<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends State<YearReviewScreen> {
  late int _selectedYear;
  late List<int> _availableYears;

  @override
  void initState() {
    super.initState();
    _availableYears = _computeAvailableYears();
    _selectedYear =
        _availableYears.isNotEmpty ? _availableYears.last : DateTime.now().year;
  }

  List<int> _computeAvailableYears() {
    final dates = widget.storageService.datesWithClips;
    if (dates.isEmpty) return [DateTime.now().year];
    final years =
        dates.map((d) => int.parse(d.substring(0, 4))).toSet().toList()..sort();
    return years;
  }

  String _startOfYear(int year) => '$year-01-01';
  String _endOfYear(int year) => '$year-12-31';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = _startOfYear(_selectedYear);
    final end = _endOfYear(_selectedYear);

    final clipsInYear = widget.storageService.getClipsInRange(start, end);
    final uniqueDates = widget.storageService.uniqueDatesInRange(start, end);
    final totalClips = clipsInYear.length;
    final daysCaptured = uniqueDates.length;
    final isLeapYear = DateTime(_selectedYear, 2, 29).month == 2;
    final daysInYear = isLeapYear ? 366 : 365;
    final captureRate =
        daysInYear > 0 ? (daysCaptured / daysInYear * 100) : 0.0;
    final longestStreak = widget.storageService.getStreakInRange(start, end);
    final locationCounts =
        widget.storageService.getLocationCountsInRange(start, end);
    final tagCounts = widget.storageService.getTagCountsInRange(start, end);
    final faceCounts = widget.storageService.getFaceCountsInRange(start, end);
    final uniqueLocations = locationCounts.length;
    final uniqueFaces = faceCounts.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'YEAR IN REVIEW',
          style: AppTheme.pixelFont(fontSize: 12),
        ),
      ),
      body: CrtOverlay(
        enabled: widget.storageService.getCrtEffects(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Year Selector
            _buildYearSelector(theme),
            const SizedBox(height: 24),

            // 2. Heatmap
            _buildSectionHeader('ACTIVITY', theme),
            const SizedBox(height: 8),
            _buildHeatmap(theme),
            const SizedBox(height: 24),

            // Streak summary below heatmap
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius:
                          AppTheme.isModern ? BorderRadius.circular(2) : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Less',
                      style: AppTheme.monoFont(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface.withOpacity(0.5))),
                  const SizedBox(width: 4),
                  for (final opacity in [0.3, 0.6, 1.0])
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(opacity),
                          borderRadius: AppTheme.isModern
                              ? BorderRadius.circular(2)
                              : null,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text('More',
                      style: AppTheme.monoFont(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface.withOpacity(0.5))),
                  const Spacer(),
                  Text(
                    'STREAK: $longestStreak',
                    style: AppTheme.monoFont(
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'RATE: ${captureRate.toStringAsFixed(0)}%',
                    style: AppTheme.monoFont(
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Monthly Bar Chart
            _buildSectionHeader('MONTHLY', theme),
            const SizedBox(height: 8),
            _buildMonthlyChart(theme),
            const SizedBox(height: 24),

            // 4. Stats Grid
            _buildSectionHeader('STATISTICS', theme),
            const SizedBox(height: 8),
            _buildStatsGrid(
              theme,
              totalClips: totalClips,
              daysCaptured: daysCaptured,
              captureRate: captureRate,
              longestStreak: longestStreak,
              uniqueLocations: uniqueLocations,
              uniqueFaces: uniqueFaces,
            ),
            const SizedBox(height: 24),

            // 5. Top Locations
            if (locationCounts.isNotEmpty) ...[
              _buildSectionHeader('TOP LOCATIONS', theme),
              const SizedBox(height: 8),
              _buildRankedList(theme, locationCounts),
              const SizedBox(height: 24),
            ],

            // 6. Top Tags
            if (tagCounts.isNotEmpty) ...[
              _buildSectionHeader('TOP TAGS', theme),
              const SizedBox(height: 8),
              _buildRankedList(theme, tagCounts),
              const SizedBox(height: 24),
            ],

            // 7. Monthly Faces
            if (faceCounts.isNotEmpty) ...[
              _buildSectionHeader('PEOPLE SPOTTED', theme),
              const SizedBox(height: 8),
              _buildFacesGrid(theme, faceCounts),
              const SizedBox(height: 24),
            ],

            // Empty state
            if (totalClips == 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.videocam_off,
                          size: 48,
                          color: theme.colorScheme.onSurface.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'NO CLIPS FOR $_selectedYear',
                        style: AppTheme.pixelFont(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start capturing to see your year in review!',
                        style: AppTheme.monoFont(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildYearSelector(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _availableYears.map((year) {
          final isSelected = year == _selectedYear;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedYear = year),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius:
                      AppTheme.isModern ? BorderRadius.circular(8) : null,
                ),
                child: Text(
                  year.toString(),
                  style: AppTheme.monoFont(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: AppTheme.pixelFont(
        fontSize: 11,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildHeatmap(ThemeData theme) {
    // GitHub-style heatmap: 52-53 columns × 7 rows
    // Jan 1 starts on its weekday, we pad before
    final jan1 = DateTime(_selectedYear, 1, 1);
    final dec31 = DateTime(_selectedYear, 12, 31);
    final startWeekday = jan1.weekday % 7; // Sunday = 0

    // Total days in year
    final totalDays = dec31.difference(jan1).inDays + 1;
    // Total cells needed: startWeekday offset + totalDays
    final totalCells = startWeekday + totalDays;
    final numWeeks = (totalCells / 7).ceil();

    const cellSize = 12.0;
    const cellGap = 2.0;
    const labelWidth = 20.0;

    final monthLabels = [
      'J',
      'F',
      'M',
      'A',
      'M',
      'J',
      'J',
      'A',
      'S',
      'O',
      'N',
      'D'
    ];
    final weekdayLabels = ['', 'M', '', 'W', '', 'F', ''];

    return RetroCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels row
          Row(
            children: [
              SizedBox(width: labelWidth),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: numWeeks * (cellSize + cellGap),
                    height: 14,
                    child: Stack(
                      children: List.generate(12, (month) {
                        final monthStart =
                            DateTime(_selectedYear, month + 1, 1);
                        final dayOfYear = monthStart.difference(jan1).inDays;
                        final weekIndex = (dayOfYear + startWeekday) ~/ 7;
                        final xPos = weekIndex * (cellSize + cellGap);
                        return Positioned(
                          left: xPos,
                          top: 0,
                          child: Text(
                            monthLabels[month],
                            style: AppTheme.monoFont(
                              fontSize: 9,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Heatmap grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekday labels
              Column(
                children: List.generate(7, (i) {
                  return SizedBox(
                    width: labelWidth,
                    height: cellSize + cellGap,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        weekdayLabels[i],
                        style: AppTheme.monoFont(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              // Grid
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _HeatmapGrid(
                    year: _selectedYear,
                    storageService: widget.storageService,
                    numWeeks: numWeeks,
                    startWeekday: startWeekday,
                    totalDays: totalDays,
                    cellSize: cellSize,
                    cellGap: cellGap,
                    primaryColor: theme.colorScheme.primary,
                    emptyColor: theme.colorScheme.onSurface.withOpacity(0.05),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(ThemeData theme) {
    final monthlyCounts = List.generate(12, (i) {
      return widget.storageService
          .getClipsForMonth(_selectedYear, i + 1)
          .length;
    });
    final maxCount = monthlyCounts.reduce((a, b) => a > b ? a : b);
    final monthNames = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];

    const maxBarHeight = 120.0;

    return RetroCard(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: maxBarHeight + 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(12, (i) {
            final count = monthlyCounts[i];
            final barHeight =
                maxCount > 0 ? (count / maxCount) * maxBarHeight : 0.0;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    Text(
                      count.toString(),
                      style: AppTheme.monoFont(
                        fontSize: 9,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Container(
                    height: barHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: AppTheme.isModern
                          ? const BorderRadius.vertical(top: Radius.circular(4))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    monthNames[i],
                    style: AppTheme.monoFont(
                      fontSize: 8,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    ThemeData theme, {
    required int totalClips,
    required int daysCaptured,
    required double captureRate,
    required int longestStreak,
    required int uniqueLocations,
    required int uniqueFaces,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatCard(
            label: 'TOTAL CLIPS', value: totalClips.toString(), theme: theme),
        _StatCard(label: 'DAYS', value: daysCaptured.toString(), theme: theme),
        _StatCard(
            label: 'RATE',
            value: '${captureRate.toStringAsFixed(1)}%',
            theme: theme),
        _StatCard(
            label: 'STREAK', value: longestStreak.toString(), theme: theme),
        _StatCard(
            label: 'LOCATIONS',
            value: uniqueLocations.toString(),
            theme: theme),
        _StatCard(label: 'PEOPLE', value: uniqueFaces.toString(), theme: theme),
      ],
    );
  }

  Widget _buildRankedList(ThemeData theme, Map<String, int> counts) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final maxVal = top5.first.value;

    return RetroCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: top5.map((entry) {
          final fraction = maxVal > 0 ? entry.value / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    entry.key,
                    style: AppTheme.monoFont(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        height: 16,
                        width: constraints.maxWidth * fraction,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.7),
                          borderRadius: AppTheme.isModern
                              ? BorderRadius.circular(4)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.value.toString(),
                  style: AppTheme.monoFont(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFacesGrid(ThemeData theme, Map<String, int> faceCounts) {
    final sorted = faceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RetroCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: sorted.map((entry) {
          final imagePath = widget.storageService.getFaceImagePath(entry.key);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: theme.colorScheme.primary, width: 2),
                ),
                child: ClipOval(
                  child: imagePath != null
                      ? ThumbnailImage(
                          path: imagePath,
                          placeholder: Icon(Icons.person,
                              color: theme.colorScheme.primary, size: 24),
                        )
                      : Icon(Icons.person,
                          color: theme.colorScheme.primary, size: 24),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.key,
                style: AppTheme.monoFont(
                    fontSize: 10, color: theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${entry.value}x',
                style: AppTheme.monoFont(
                    fontSize: 9, color: theme.colorScheme.primary),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _StatCard(
      {required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 3,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          borderRadius: AppTheme.isModern ? BorderRadius.circular(8) : null,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTheme.displayFont(
                fontSize: 24,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.monoFont(
                fontSize: 9,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final int year;
  final StorageService storageService;
  final int numWeeks;
  final int startWeekday;
  final int totalDays;
  final double cellSize;
  final double cellGap;
  final Color primaryColor;
  final Color emptyColor;

  const _HeatmapGrid({
    required this.year,
    required this.storageService,
    required this.numWeeks,
    required this.startWeekday,
    required this.totalDays,
    required this.cellSize,
    required this.cellGap,
    required this.primaryColor,
    required this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: numWeeks * (cellSize + cellGap),
      height: 7 * (cellSize + cellGap),
      child: CustomPaint(
        painter: _HeatmapPainter(
          year: year,
          storageService: storageService,
          numWeeks: numWeeks,
          startWeekday: startWeekday,
          totalDays: totalDays,
          cellSize: cellSize,
          cellGap: cellGap,
          primaryColor: primaryColor,
          emptyColor: emptyColor,
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final int year;
  final StorageService storageService;
  final int numWeeks;
  final int startWeekday;
  final int totalDays;
  final double cellSize;
  final double cellGap;
  final Color primaryColor;
  final Color emptyColor;

  _HeatmapPainter({
    required this.year,
    required this.storageService,
    required this.numWeeks,
    required this.startWeekday,
    required this.totalDays,
    required this.cellSize,
    required this.cellGap,
    required this.primaryColor,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final jan1 = DateTime(year, 1, 1);

    for (var dayIndex = 0; dayIndex < totalDays; dayIndex++) {
      final date = jan1.add(Duration(days: dayIndex));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final count = storageService.clipCountForDate(dateStr);

      final cellIndex = dayIndex + startWeekday;
      final week = cellIndex ~/ 7;
      final weekday = cellIndex % 7;

      final x = week * (cellSize + cellGap);
      final y = weekday * (cellSize + cellGap);

      Color color;
      if (count == 0) {
        color = emptyColor;
      } else if (count == 1) {
        color = primaryColor.withOpacity(0.3);
      } else if (count == 2) {
        color = primaryColor.withOpacity(0.6);
      } else {
        color = primaryColor;
      }

      final rect = Rect.fromLTWH(x, y, cellSize, cellSize);
      final paint = Paint()..color = color;

      if (AppTheme.isModern) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      } else {
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.year != year || old.primaryColor != primaryColor;
}
