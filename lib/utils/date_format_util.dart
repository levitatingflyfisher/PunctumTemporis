import 'package:intl/intl.dart';

enum DateFormatOption {
  mmmDd,
  dMmm,
  mmmDYyyy,
  fullOrdinal,
  ddMmmYyyy,
  yyyyMmmDd,
  yyyyMmDd,
  isoDate,
  mmDdYyyy,
  slashMmDdYyyy,
}

class DateFormatUtil {
  static String format(DateTime date, DateFormatOption option) {
    switch (option) {
      case DateFormatOption.mmmDd:
        return DateFormat('MMM dd').format(date);
      case DateFormatOption.dMmm:
        return '${date.day} ${DateFormat('MMM').format(date)}';
      case DateFormatOption.mmmDYyyy:
        return DateFormat('MMM d, yyyy').format(date);
      case DateFormatOption.fullOrdinal:
        final suffix = _ordinalSuffix(date.day);
        return '${DateFormat('MMMM').format(date)} ${date.day}$suffix, ${date.year}';
      case DateFormatOption.ddMmmYyyy:
        return '${date.day.toString().padLeft(2, '0')}${DateFormat('MMM').format(date).toUpperCase()}${date.year}';
      case DateFormatOption.yyyyMmmDd:
        return '${date.year}${DateFormat('MMM').format(date).toUpperCase()}${date.day.toString().padLeft(2, '0')}';
      case DateFormatOption.yyyyMmDd:
        return DateFormat('yyyyMMdd').format(date);
      case DateFormatOption.isoDate:
        return DateFormat('yyyy-MM-dd').format(date);
      case DateFormatOption.mmDdYyyy:
        return DateFormat('MM-dd-yyyy').format(date);
      case DateFormatOption.slashMmDdYyyy:
        return DateFormat('MM/dd/yyyy').format(date);
    }
  }

  static String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  static String toKey(DateFormatOption option) => option.name;

  static DateFormatOption fromKey(String key) {
    return DateFormatOption.values.firstWhere(
      (e) => e.name == key,
      orElse: () => DateFormatOption.ddMmmYyyy,
    );
  }

  static String label(DateFormatOption option) {
    final sample = DateTime(2026, 1, 6);
    return format(sample, option);
  }
}
