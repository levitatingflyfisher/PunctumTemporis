/// Whole calendar days from [a] to [b], DST-safe. Both dates are reduced to
/// their **UTC midnight** before subtracting, so a daylight-saving transition
/// between them can never add or drop the hour that would skew a naive
/// `b.difference(a).inDays` (which truncates 167h to 6, not 7). Positive when
/// [b] is the later date; the calendar day is all that matters, times are
/// ignored.
int daysBetweenDates(DateTime a, DateTime b) {
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ub.difference(ua).inDays;
}

/// [date]'s calendar day as a **UTC midnight**. In UTC every day is exactly
/// 24 hours, so `Duration`-stepping from this value always lands exactly one
/// calendar day away — unlike stepping a local DateTime, which drifts an
/// hour across a DST transition and can skip (or repeat) a wall-clock day.
/// Only the year/month/day fields are meaningful; format with a
/// field-reading formatter (e.g. `yyyy-MM-dd`), never convert back to local.
DateTime utcMidnight(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
