// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:intl/intl.dart';

/// Smart date formatting utilities following Material Design 3 guidelines
class DateFormatters {
  /// Formats a time according to the user's 12h/24h preference.
  static String formatTime(DateTime date, {bool use24Hour = false}) {
    return use24Hour
        ? DateFormat('HH:mm').format(date)
        : DateFormat('h:mm a').format(date);
  }

  /// Formats a TimeOfDay according to the user's 12h/24h preference.
  static String formatTimeOfDay(
    int hour,
    int minute, {
    bool use24Hour = false,
  }) {
    final minuteStr = minute.toString().padLeft(2, '0');
    if (use24Hour) {
      return '${hour.toString().padLeft(2, '0')}:$minuteStr';
    } else {
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minuteStr $period';
    }
  }

  /// Formats an hour (0-23) as a label for timetable display.
  static String formatHourLabel(int hour, {bool use24Hour = false}) {
    if (use24Hour) {
      return '${hour.toString().padLeft(2, '0')}:00';
    } else {
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour $period';
    }
  }

  static String formatSmart(
    DateTime date, {
    DateTime? now,
    bool includeTime = true,
    bool use24Hour = false,
  }) {
    now ??= DateTime.now();

    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    final difference = dateOnly.difference(todayOnly).inDays;

    final timeStr = includeTime && (date.hour != 0 || date.minute != 0)
        ? ' at ${formatTime(date, use24Hour: use24Hour)}'
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
