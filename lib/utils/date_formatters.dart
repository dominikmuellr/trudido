import 'package:intl/intl.dart';

/// Smart date formatting utilities following Material Design 3 guidelines
class DateFormatters {
  /// Formats a date relative to now, showing "Today", "Tomorrow", "Yesterday" when appropriate
  ///
  /// Examples:
  /// - Today at 3:30 PM
  /// - Tomorrow at 10:00 AM
  /// - Yesterday at 5:45 PM
  /// - Wed, Oct 30 at 2:15 PM
  /// - Oct 30, 2025
  static String formatSmart(
    DateTime date, {
    DateTime? now,
    bool includeTime = true,
  }) {
    now ??= DateTime.now();

    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    final difference = dateOnly.difference(todayOnly).inDays;

    final timeStr = includeTime && (date.hour != 0 || date.minute != 0)
        ? ' at ${DateFormat.jm().format(date)}' // 3:30 PM
        : '';

    if (difference == 0) {
      return 'Today$timeStr';
    } else if (difference == 1) {
      return 'Tomorrow$timeStr';
    } else if (difference == -1) {
      return 'Yesterday$timeStr';
    } else if (difference > 0 && difference <= 6) {
      // Within next week: "Wed, Oct 30 at 2:15 PM"
      return DateFormat('EEE, MMM d').format(date) + timeStr;
    } else if (difference < 0 && difference >= -6) {
      // Within past week: "Mon, Oct 28 at 2:15 PM"
      return DateFormat('EEE, MMM d').format(date) + timeStr;
    } else if (date.year == now.year) {
      // Same year: "Oct 30 at 2:15 PM"
      return DateFormat('MMM d').format(date) + timeStr;
    } else {
      // Different year: "Oct 30, 2025 at 2:15 PM"
      return DateFormat('MMM d, yyyy').format(date) + timeStr;
    }
  }

  /// Formats a date range smartly
  ///
  /// Examples:
  /// - Today → Tomorrow
  /// - Oct 28 → Oct 30
  /// - Oct 28 → Nov 2
  static String formatSmartRange(
    DateTime start,
    DateTime end, {
    DateTime? now,
  }) {
    now ??= DateTime.now();

    final startStr = formatSmart(start, now: now, includeTime: false);
    final endStr = formatSmart(end, now: now, includeTime: false);

    return '$startStr → $endStr';
  }

  /// Returns a short relative label suitable for chips
  ///
  /// Examples:
  /// - Today
  /// - Tomorrow
  /// - Oct 30
  /// - Wed
  static String formatChip(DateTime date, {DateTime? now}) {
    now ??= DateTime.now();

    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    final difference = dateOnly.difference(todayOnly).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 0 && difference <= 6) {
      // Within next week: show day name
      return DateFormat.E().format(date); // "Wed"
    } else if (difference < 0 && difference >= -6) {
      // Within past week: show day name
      return DateFormat.E().format(date); // "Mon"
    } else if (date.year == now.year) {
      // Same year: "Oct 30"
      return DateFormat('MMM d').format(date);
    } else {
      // Different year: "Oct 30, 2025"
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  /// Returns a Material Design 3 compliant date range string
  static String formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      // Same month: "Oct 28–30, 2025"
      return '${DateFormat('MMM d').format(start)}–${DateFormat('d, yyyy').format(end)}';
    } else if (start.year == end.year) {
      // Same year: "Oct 28 – Nov 2, 2025"
      return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
    } else {
      // Different years: "Dec 28, 2025 – Jan 2, 2026"
      return '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
    }
  }

  /// Returns duration in a human-readable format
  static String formatDuration(Duration duration) {
    final days = duration.inDays;
    if (days == 0) {
      return 'Same day';
    } else if (days == 1) {
      return '1 day';
    } else {
      return '$days days';
    }
  }
}
