import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture subtitle constants do not contain misleading 1 second text', () {
    const recordSubtitle = 'Tap and hold to record';
    expect(recordSubtitle, isNot(contains('1 second clip')));

    const photoSubtitle = 'Still image as a clip';
    expect(photoSubtitle, isNot(contains('Convert to 1s')));
  });
}
