// Chrome outshouted data and the quiet text was too quiet (audit finding
// 10): about 77 lines of text sat at onSurface alpha 0.25 to 0.6, under the
// fleet's 4.5:1 floor, and every setting tile and stat card wore an accent
// border. Ruling (batch 2): one dim-text role at 4.5:1 or better, and the
// accent borders go.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  tearDown(() => AppTheme.visualStyle = 'hearth');

  for (final style in ['hearth', 'retro', 'modern']) {
    for (final b in Brightness.values) {
      test('$style ${b.name}: dim text reads at 4.5:1 on every ground', () {
        AppTheme.visualStyle = style;
        final theme = AppTheme.buildTheme(b, const Color(0xFF00FF41));
        final cs = theme.colorScheme;
        for (final ground in {
          'surface': cs.surface,
          'container': cs.surfaceContainerHighest,
          'scaffold': theme.scaffoldBackgroundColor,
        }.entries) {
          final ink = Color.alphaBlend(AppTheme.dimInk(theme), ground.value);
          expect(_ratio(ink, ground.value), greaterThanOrEqualTo(4.5),
              reason: '${ground.key} ${ground.value}');
        }
      });
    }
  }

  test('no faint onSurface text without a stated reason', () {
    final faint = RegExp(r'onSurface\s*\.withValues\(alpha:\s*0\.[0-6]\d*\)');
    final hits = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      final lines = src.split('\n');
      for (final m in faint.allMatches(src)) {
        final line = '\n'.allMatches(src.substring(0, m.start)).length;
        final window = lines.sublist(math.max(0, line - 6), line + 1).join('\n');
        if (!window.contains('contrast-exempt:')) hits.add('${f.path}:${line + 1}');
      }
    }
    expect(hits, isEmpty,
        reason: 'use AppTheme.dimInk(theme), or mark a disabled or '
            'decorative mark with // contrast-exempt: <why>');
  });

  test('setting tiles and stat cards carry no accent border', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final tile = settings.substring(settings.indexOf('Widget _buildSettingTile('),
        settings.indexOf('Widget _buildStatTile('));
    expect(tile, isNot(contains('Border.all(')));
    final review = File('lib/screens/year_review_screen.dart').readAsStringSync();
    final card = review.substring(review.indexOf('class _StatCard'));
    expect(card.substring(0, card.indexOf('\n}')), isNot(contains('Border.all(')));
  });
}
