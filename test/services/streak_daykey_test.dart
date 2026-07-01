import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_a_day/models/clip.dart';
import 'package:one_second_a_day/services/storage_service.dart';
import 'package:one_second_a_day/utils/date_arithmetic.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Streak day-walk correctness across DST transitions.
///
/// The failure class (documented in Bulwark's datetime_ext): subtracting
/// `Duration(days: 1)` from a LOCAL DateTime steps exactly 24 elapsed hours,
/// but across a daylight-saving transition a calendar day is 23 or 25 wall
/// hours long. The elapsed-hours/24 truncation then miscounts calendar days
/// (167 hours spanning 7 calendar days truncates to 6), and a backward
/// day-walk can skip a day key entirely — silently breaking a real streak.
///
/// These tests are TZ-independent for the fixed code: all expectations hold
/// whatever the host timezone. To REPRODUCE the old defect on the old code,
/// run them under a DST timezone, e.g. `TZ=America/New_York flutter test`.
void main() {
  Clip clipOn(String isoDate) => Clip(
        id: 'c-$isoDate',
        date: isoDate,
        filePath: '/clips/$isoDate.mp4',
        thumbnailPath: null,
        type: ClipType.video,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<StorageService> storageWith(List<String> dates) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    storage.setClipsForTest({
      for (final d in dates) d: [clipOn(d)],
    });
    return storage;
  }

  group('daysBetweenDates — calendar days, not elapsed-hours/24', () {
    test(
        'two timestamps 167 wall-clock hours apart spanning 7 calendar days '
        'count as 7 (naive inDays truncates to 6)', () {
      // 2026-03-08 01:00 -> 2026-03-15 00:00 spans 7 calendar days but only
      // ~167 elapsed hours (166 in a US-DST zone; 167 in a fixed-offset
      // zone) — either way `difference().inDays` truncates to 6.
      final a = DateTime(2026, 3, 8, 1, 0);
      final b = DateTime(2026, 3, 15, 0, 0);
      expect(b.difference(a).inDays, lessThan(7),
          reason: 'precondition: the naive arithmetic really does truncate');
      expect(daysBetweenDates(a, b), 7);
    });

    test('same calendar day is 0 regardless of times', () {
      expect(
        daysBetweenDates(
            DateTime(2026, 3, 8, 23, 59), DateTime(2026, 3, 8, 0, 1)),
        0,
      );
    });

    test('adjacent calendar days are 1 even with a 25-hour wall gap', () {
      // Fall-back shape: late evening -> next-day late evening.
      expect(
        daysBetweenDates(
            DateTime(2026, 11, 1, 0, 30), DateTime(2026, 11, 2, 1, 30)),
        1,
      );
    });
  });

  group('getCurrentStreak — walks calendar days, never skips a day key', () {
    test(
        'seven consecutive clip days spanning a spring-forward boundary '
        'count as a 7-day streak (old Duration-walk skipped the DST day)',
        () async {
      // 2026-03-04 .. 2026-03-10 — spans the US spring-forward (2026-03-08).
      final storage = await storageWith([
        '2026-03-04',
        '2026-03-05',
        '2026-03-06',
        '2026-03-07',
        '2026-03-08',
        '2026-03-09',
        '2026-03-10',
      ]);
      // Shortly after midnight: under a DST zone, subtracting 24h from here
      // lands at 23:30 two calendar days back, skipping a day key.
      final now = DateTime(2026, 3, 10, 0, 30);
      expect(storage.getCurrentStreak(now: now), 7);
    });

    test('streak across a month boundary uses calendar arithmetic', () async {
      final storage = await storageWith([
        '2026-02-26',
        '2026-02-27',
        '2026-02-28',
        '2026-03-01',
        '2026-03-02',
      ]);
      expect(storage.getCurrentStreak(now: DateTime(2026, 3, 2, 12)), 5);
    });

    test('morning grace still applies with the calendar-safe walk', () async {
      // No clip on the 10th ("today") yet — count from the 9th backward.
      final storage = await storageWith([
        '2026-03-07',
        '2026-03-08',
        '2026-03-09',
      ]);
      expect(storage.getCurrentStreak(now: DateTime(2026, 3, 10, 0, 30)), 3);
    });
  });

  group('getLongestStreak — same truncation class', () {
    test(
        'seven consecutive stored day keys spanning spring-forward are one '
        '7-day run (old inDays saw a 23-hour "0-day" gap and split it)',
        () async {
      final storage = await storageWith([
        '2026-03-06',
        '2026-03-07',
        '2026-03-08',
        '2026-03-09',
        '2026-03-10',
        '2026-03-11',
        '2026-03-12',
      ]);
      expect(storage.getLongestStreak(), 7);
    });
  });
}
