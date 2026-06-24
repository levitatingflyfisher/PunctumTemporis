import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/screens/compilation_screen.dart';

void main() {
  group('season label', () {
    test('March is spring', () {
      expect(CompilationScreen.seasonLabel(DateTime(2026, 3, 19)), 'SPRING (MAR-MAY)');
    });
    test('December is winter', () {
      expect(CompilationScreen.seasonLabel(DateTime(2026, 12, 1)), 'WINTER (DEC-FEB)');
    });
    test('July is summer', () {
      expect(CompilationScreen.seasonLabel(DateTime(2026, 7, 1)), 'SUMMER (JUN-AUG)');
    });
    test('October is fall', () {
      expect(CompilationScreen.seasonLabel(DateTime(2026, 10, 1)), 'FALL (SEP-NOV)');
    });
  });
}
