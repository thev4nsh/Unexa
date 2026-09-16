import 'package:intl/intl.dart';

/// Formatter utilities for UNEXA timetable and calendar schedules.
class DateFormatter {
  /// Format a DateTime to "Thursday, Sep 12"
  static String formatShortDate(DateTime date) {
    return DateFormat('EEEE, MMM d').format(date);
  }

  /// Format a DateTime to "Thursday, 12 September 2026"
  static String formatFullDate(DateTime date) {
    return DateFormat('EEEE, d MMMM yyyy').format(date);
  }

  /// Format a date to "12 Sep 2026"
  static String formatCompactDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Format time range: "10:00 AM - 11:00 AM"
  static String formatTimeRange(String startTime, String endTime) {
    return '$startTime – $endTime';
  }

  /// Returns English weekday name: 'Monday', 'Tuesday', etc.
  static String currentDayName([DateTime? date]) {
    final target = date ?? DateTime.now();
    return DateFormat('EEEE').format(target);
  }

  /// Parse a time string like "10:00 AM" or "14:30" into a TimeOfDay / minutes from midnight.
  static int? parseMinutesFromMidnight(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final parts = clean.replaceAll('AM', '').replaceAll('PM', '').trim().split(':');
      if (parts.length >= 2) {
        int hours = int.parse(parts[0].trim());
        int minutes = int.parse(parts[1].trim());
        if (isPm && hours < 12) hours += 12;
        if (isAm && hours == 12) hours = 0;
        return hours * 60 + minutes;
      }
    } catch (_) {}
    return null;
  }

  /// Human-readable upcoming class relative indicator (e.g. "Starts in 45m" or "Ongoing")
  static String getRelativeClassStatus(String startTimeStr, String endTimeStr, [DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    final startMinutes = parseMinutesFromMidnight(startTimeStr);
    final endMinutes = parseMinutesFromMidnight(endTimeStr);

    if (startMinutes == null || endMinutes == null) return '';

    if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
      return 'Ongoing now';
    } else if (currentMinutes < startMinutes) {
      final diff = startMinutes - currentMinutes;
      if (diff <= 60) {
        return 'Starts in ${diff}m';
      } else {
        final hrs = (diff / 60).floor();
        final mins = diff % 60;
        return mins > 0 ? 'Starts in ${hrs}h ${mins}m' : 'Starts in ${hrs}h';
      }
    } else {
      return 'Completed';
    }
  }
}
