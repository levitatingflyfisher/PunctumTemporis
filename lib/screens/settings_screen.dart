import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../utils/date_format_util.dart';
import '../widgets/crt_effects.dart';
import 'year_review_screen.dart';
import 'backup_restore_screen.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final void Function(int mode, Color accent) onThemeChanged;
  final VoidCallback? onVisualStyleChanged;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.onThemeChanged,
    this.onVisualStyleChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _themeMode;
  late Color _accentColor;
  late bool _crtEffects;
  late String _dateFormat;
  late bool _captureLocation;
  late String _visualStyle;
  late bool _reminderEnabled;
  late TimeOfDay _reminderTime;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.storageService.getThemeMode();
    _accentColor = Color(widget.storageService.getAccentColor());
    _crtEffects = widget.storageService.getCrtEffects();
    _dateFormat = widget.storageService.getDateFormat();
    _captureLocation = widget.storageService.getCaptureLocation();
    _visualStyle = widget.storageService.getVisualStyle();
    _reminderEnabled = widget.storageService.getReminderEnabled();
    _reminderTime = widget.storageService.getReminderTime();
  }

  void _updateTheme() {
    widget.onThemeChanged(_themeMode, _accentColor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: AppTheme.pixelFont(fontSize: 12),
        ),
      ),
      body: CrtOverlay(
        enabled: _crtEffects,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Appearance section
            _buildSectionHeader('APPEARANCE'),

            // Theme mode
            _buildSettingTile(
              label: 'Theme',
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('DARK')),
                  ButtonSegment(value: 1, label: Text('LIGHT')),
                  ButtonSegment(value: 2, label: Text('SYSTEM')),
                ],
                selected: {_themeMode},
                onSelectionChanged: (selection) {
                  setState(() => _themeMode = selection.first);
                  widget.storageService.setThemeMode(_themeMode);
                  _updateTheme();
                },
                style: ButtonStyle(
                  textStyle: WidgetStatePropertyAll(
                    AppTheme.monoFont(fontSize: 10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Accent color
            if (!AppTheme.isHearth)
              _buildSettingTile(
                label: 'Accent Color',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppTheme.accentPresets.entries.map((entry) {
                    final isSelected = _accentColor.value == entry.value.value;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _accentColor = entry.value);
                        widget.storageService.setAccentColor(entry.value.value);
                        _updateTheme();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: entry.value,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: entry.value.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              _buildSettingTile(
                label: 'Accent Color',
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.hearthPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Fixed Hearth terracotta',
                      style: AppTheme.monoFont(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Visual style
            _buildSettingTile(
              label: 'Visual Style',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'retro', label: Text('RETRO')),
                  ButtonSegment(value: 'modern', label: Text('MODERN')),
                  ButtonSegment(value: 'hearth', label: Text('HEARTH')),
                ],
                selected: {_visualStyle},
                onSelectionChanged: (selection) {
                  setState(() => _visualStyle = selection.first);
                  widget.storageService.setVisualStyle(_visualStyle);
                  AppTheme.visualStyle = _visualStyle;
                  _updateTheme();
                  widget.onVisualStyleChanged?.call();
                },
                style: ButtonStyle(
                  textStyle: WidgetStatePropertyAll(
                    AppTheme.monoFont(fontSize: 11),
                  ),
                ),
              ),
            ),

            if (AppTheme.isRetro) ...[
              const SizedBox(height: 16),
              _buildSettingTile(
                label: 'CRT Scanlines',
                trailing: Switch(
                  value: _crtEffects,
                  onChanged: (value) {
                    setState(() => _crtEffects = value);
                    widget.storageService.setCrtEffects(value);
                  },
                  activeColor: theme.colorScheme.primary,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Date overlay format
            _buildSettingTile(
              label: 'Date Overlay Format',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DateFormatOption.values.map((option) {
                  final key = DateFormatUtil.toKey(option);
                  final isSelected = _dateFormat == key;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _dateFormat = key);
                      widget.storageService.setDateFormat(key);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        DateFormatUtil.label(option),
                        style: AppTheme.monoFont(
                          fontSize: 11,
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Capture location
            _buildSettingTile(
              label: 'Capture Location',
              trailing: Switch(
                value: _captureLocation,
                onChanged: (value) {
                  setState(() => _captureLocation = value);
                  widget.storageService.setCaptureLocation(value);
                },
                activeColor: theme.colorScheme.primary,
              ),
            ),

            const SizedBox(height: 32),

            // Reminders section
            _buildSectionHeader('REMINDERS'),

            _buildSettingTile(
              label: 'Daily Reminder',
              trailing: Switch(
                value: _reminderEnabled,
                onChanged: (value) async {
                  setState(() => _reminderEnabled = value);
                  await widget.storageService.setReminderEnabled(value);
                  if (value) {
                    await NotificationService.instance
                        .scheduleDailyReminder(_reminderTime);
                  } else {
                    await NotificationService.instance.cancelReminder();
                  }
                },
                activeColor: theme.colorScheme.primary,
              ),
            ),

            if (_reminderEnabled) ...[
              const SizedBox(height: 8),
              _buildSettingTile(
                label: 'Reminder Time',
                trailing: GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _reminderTime,
                    );
                    if (picked != null) {
                      setState(() => _reminderTime = picked);
                      await widget.storageService.setReminderTime(picked);
                      await NotificationService.instance
                          .scheduleDailyReminder(picked);
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.primary),
                      borderRadius:
                          !AppTheme.isRetro ? BorderRadius.circular(6) : null,
                    ),
                    child: Text(
                      _reminderTime.format(context),
                      style: AppTheme.monoFont(
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Data section
            _buildSectionHeader('DATA'),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BackupRestoreScreen(
                      storageService: widget.storageService,
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.backup,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Backup & Restore',
                          style: AppTheme.monoFont(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Stats section
            _buildSectionHeader('STATISTICS'),

            _buildStatTile(
              label: 'Total Clips',
              value: widget.storageService.totalClips.toString(),
            ),
            _buildStatTile(
              label: 'Current Streak',
              value: '${widget.storageService.getCurrentStreak()} days',
            ),
            _buildStatTile(
              label: 'Longest Streak',
              value: '${widget.storageService.getLongestStreak()} days',
            ),
            _buildStatTile(
              label: 'Compilations',
              value: widget.storageService.compilations.length.toString(),
            ),

            const SizedBox(height: 16),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => YearReviewScreen(
                      storageService: widget.storageService,
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Year in Review',
                          style: AppTheme.monoFont(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Storage section
            _buildSectionHeader('STORAGE'),

            _buildSettingTile(
              label: 'Clips Location',
              trailing: Text(
                widget.storageService.clipsPath.split('/').last,
                style: AppTheme.monoFont(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // About section
            _buildSectionHeader('ABOUT'),

            _buildSettingTile(
              label: 'Version',
              trailing: Text(
                '1.3.0',
                style: AppTheme.monoFont(fontSize: 14),
              ),
            ),

            _buildSettingTile(
              label: 'License',
              trailing: Text(
                'MIT License',
                style: AppTheme.monoFont(fontSize: 14),
              ),
            ),

            const SizedBox(height: 32),

            // Footer with logo
            Center(
              child: SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: _AppLogoPainter(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    backgroundColor: theme.scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                'ONE SECOND A DAY',
                style: AppTheme.pixelFont(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: Text(
                'FOSS • LOCAL-FIRST • NO TELEMETRY',
                style: AppTheme.monoFont(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
            ),
          ],
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

  Widget _buildSettingTile({
    required String label,
    Widget? child,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.2),
          ),
          borderRadius: AppTheme.isHearth ? BorderRadius.circular(12) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: AppTheme.displayFont(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({required String label, required String value}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTheme.monoFont(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            Text(
              value,
              style: AppTheme.displayFont(
                fontSize: 18,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App logo: hourglass with snowflake on left + shine lines on right
class _AppLogoPainter extends CustomPainter {
  final Color color;
  final Color backgroundColor;

  _AppLogoPainter({required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width / 64;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // --- LAYER 1: Snowflake (behind hourglass) ---
    final snowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s
      ..strokeCap = StrokeCap.round;

    final sx = cx - 12 * s; // snowflake center, shifted left
    final arm = 14.0 * s;
    for (int i = 0; i < 3; i++) {
      final angle = i * 3.14159 / 3;
      final dx = arm * cos(angle);
      final dy = arm * sin(angle);
      canvas.drawLine(
          Offset(sx - dx, cy - dy), Offset(sx + dx, cy + dy), snowPaint);

      // Branches at 68%
      final bx = dx * 0.68;
      final by = dy * 0.68;
      final brLen = 3.5 * s;
      for (final dir in [-1.0, 1.0]) {
        final perpX = -dy / arm * brLen * dir;
        final perpY = dx / arm * brLen * dir;
        canvas.drawLine(
          Offset(sx + bx, cy + by),
          Offset(sx + bx + perpX, cy + by + perpY),
          snowPaint,
        );
        canvas.drawLine(
          Offset(sx - bx, cy - by),
          Offset(sx - bx + perpX, cy - by + perpY),
          snowPaint,
        );
      }
    }
    canvas.drawCircle(Offset(sx, cy), 1.5 * s, dotPaint);

    // --- LAYER 2: Hourglass white fill (masks snowflake) ---
    // Use the actual scaffold background color to mask the snowflake behind
    // the hourglass — must match the surface the logo is painted on.
    final maskPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    // Top half mask
    final topMask = Path()
      ..moveTo(cx - 18 * s, cy - 29 * s)
      ..lineTo(cx + 18 * s, cy - 29 * s)
      ..lineTo(cx + 18 * s, cy - 27 * s)
      ..cubicTo(cx + 18 * s, cy - 27 * s, cx + 16 * s, cy - 10 * s, cx + 4 * s,
          cy - 1 * s)
      ..lineTo(cx - 4 * s, cy - 1 * s)
      ..cubicTo(cx - 16 * s, cy - 10 * s, cx - 18 * s, cy - 27 * s, cx - 18 * s,
          cy - 27 * s)
      ..close();
    canvas.drawPath(topMask, maskPaint);

    // Bottom half mask
    final bottomMask = Path()
      ..moveTo(cx - 4 * s, cy + 1 * s)
      ..cubicTo(cx - 16 * s, cy + 10 * s, cx - 18 * s, cy + 27 * s, cx - 18 * s,
          cy + 27 * s)
      ..lineTo(cx - 18 * s, cy + 29 * s)
      ..lineTo(cx + 18 * s, cy + 29 * s)
      ..lineTo(cx + 18 * s, cy + 27 * s)
      ..cubicTo(cx + 18 * s, cy + 27 * s, cx + 16 * s, cy + 10 * s, cx + 4 * s,
          cy + 1 * s)
      ..close();
    canvas.drawPath(bottomMask, maskPaint);

    // Neck mask
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 9 * s, height: 3 * s),
      maskPaint,
    );

    // --- LAYER 3: Hourglass stroke outline ---
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Top cap
    canvas.drawLine(
      Offset(cx - 18 * s, cy - 28 * s),
      Offset(cx + 18 * s, cy - 28 * s),
      strokePaint,
    );
    // Bottom cap
    canvas.drawLine(
      Offset(cx - 18 * s, cy + 28 * s),
      Offset(cx + 18 * s, cy + 28 * s),
      strokePaint,
    );

    // Left glass curve
    final leftGlass = Path()
      ..moveTo(cx - 17 * s, cy - 27 * s)
      ..cubicTo(cx - 17 * s, cy - 27 * s, cx - 16 * s, cy - 10 * s, cx - 4 * s,
          cy - 1 * s)
      ..cubicTo(cx - 3 * s, cy, cx - 3 * s, cy, cx - 4 * s, cy + 1 * s)
      ..cubicTo(cx - 16 * s, cy + 10 * s, cx - 17 * s, cy + 27 * s, cx - 17 * s,
          cy + 27 * s);
    canvas.drawPath(leftGlass, strokePaint);

    // Right glass curve
    final rightGlass = Path()
      ..moveTo(cx + 17 * s, cy - 27 * s)
      ..cubicTo(cx + 17 * s, cy - 27 * s, cx + 16 * s, cy - 10 * s, cx + 4 * s,
          cy - 1 * s)
      ..cubicTo(cx + 3 * s, cy, cx + 3 * s, cy, cx + 4 * s, cy + 1 * s)
      ..cubicTo(cx + 16 * s, cy + 10 * s, cx + 17 * s, cy + 27 * s, cx + 17 * s,
          cy + 27 * s);
    canvas.drawPath(rightGlass, strokePaint);

    // --- LAYER 4: Sparkle (upper right) ---
    final sparklePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * s
      ..strokeCap = StrokeCap.round;

    final spx = cx + 27 * s;
    final spy = cy - 26 * s;
    // Vertical ray
    canvas.drawLine(
        Offset(spx, spy - 5 * s), Offset(spx, spy + 5 * s), sparklePaint);
    // Horizontal ray
    canvas.drawLine(
        Offset(spx - 5 * s, spy), Offset(spx + 5 * s, spy), sparklePaint);
    // Diagonal NW-SE
    final sparkleThin = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(spx - 3.2 * s, spy - 3.2 * s),
        Offset(spx + 3.2 * s, spy + 3.2 * s), sparkleThin);
    // Diagonal NE-SW
    canvas.drawLine(Offset(spx + 3.2 * s, spy - 3.2 * s),
        Offset(spx - 3.2 * s, spy + 3.2 * s), sparkleThin);
    // Center dot
    canvas.drawCircle(Offset(spx, spy), 1.0 * s, dotPaint);

    // Small secondary sparkle
    final sp2x = cx + 34 * s;
    final sp2y = cy - 17 * s;
    final tinyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(sp2x, sp2y - 2.5 * s), Offset(sp2x, sp2y + 2.5 * s), tinyPaint);
    canvas.drawLine(
        Offset(sp2x - 2.5 * s, sp2y), Offset(sp2x + 2.5 * s, sp2y), tinyPaint);
    canvas.drawCircle(Offset(sp2x, sp2y), 0.5 * s, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.backgroundColor != backgroundColor;
}
