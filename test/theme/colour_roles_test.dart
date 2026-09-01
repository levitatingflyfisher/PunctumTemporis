// One red for errors (fleet colour language, openhearth_design 0.7.0).
//
// PT builds its own ThemeData, so before this it had no OhColorRoles: the
// shared OhErrorState fell back to ohStyle's urgency red while PT painted
// its own errors 0xFFFF4444, two different reds in one app, and C12
// measured an urgency colour PT never rendered. Every style and brightness
// now attaches the roles and points colorScheme.error at their urgency.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/theme/app_theme.dart';
import 'package:openhearth_design/openhearth_design.dart';

void main() {
  tearDown(() => AppTheme.visualStyle = 'hearth');

  for (final style in ['hearth', 'retro', 'modern']) {
    for (final brightness in Brightness.values) {
      test('$style ${brightness.name}: error is the urgency role', () {
        AppTheme.visualStyle = style;
        final theme =
            AppTheme.buildTheme(brightness, const Color(0xFF00FF00));
        final roles = theme.extension<OhColorRoles>();
        expect(roles, isNotNull, reason: 'OhColorRoles not attached');
        final expected = brightness == Brightness.dark
            ? OhColorRoles.hearthDark
            : OhColorRoles.light;
        expect(roles!.urgency, expected.urgency);
        expect(theme.colorScheme.error, roles.urgency);
        expect(theme.colorScheme.onError, roles.onUrgency);
      });
    }
  }
}
