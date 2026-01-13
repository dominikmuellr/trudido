// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
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

import 'package:flutter/foundation.dart';
import '../models/holiday.dart';
import '../models/todo.dart';
import 'imported_calendar_colors.dart';

/// Result of parsing an ICS file
class IcsParseResult {
  final List<Holiday> holidays;
  final String? calendarName;
  final int totalEvents;
  final int skippedEvents;
  final String? error;

  IcsParseResult({
    required this.holidays,
    this.calendarName,
    required this.totalEvents,
    required this.skippedEvents,
    this.error,
  });

  bool get success => error == null && holidays.isNotEmpty;
}

/// Result of parsing an ICS file as Todo objects
class IcsParseResultTodos {
  final List<Todo> todos;
  final String? calendarName;
  final int totalEvents;
  final int skippedEvents;
  final String? error;

  IcsParseResultTodos({
    required this.todos,
    this.calendarName,
    required this.totalEvents,
    required this.skippedEvents,
    this.error,
  });

  bool get success => error == null && todos.isNotEmpty;
}

/// Utility class for parsing ICS (iCalendar) files
class IcsParser {
  /// Parse ICS content string and extract holidays
  static IcsParseResult parse(
    String icsContent, {
    required String sourceCalendar,
  }) {
    try {
      final holidays = <Holiday>[];
      String? calendarName;
      int totalEvents = 0;
      int skippedEvents = 0;

      // Normalize line endings and unfold long lines (RFC 5545)
      final normalizedContent = _unfoldLines(icsContent);
      final lines = normalizedContent.split('\n');

      // Extract calendar name from X-WR-CALNAME if present
      for (final line in lines) {
        if (line.startsWith('X-WR-CALNAME:')) {
          calendarName = line.substring('X-WR-CALNAME:'.length).trim();
          break;
        }
      }

      // Find and parse all VEVENT blocks
      int i = 0;
      while (i < lines.length) {
        if (lines[i].trim() == 'BEGIN:VEVENT') {
          totalEvents++;
          final eventLines = <String>[];
          i++;

          while (i < lines.length && lines[i].trim() != 'END:VEVENT') {
            eventLines.add(lines[i]);
            i++;
          }

          final holiday = _parseEvent(eventLines, sourceCalendar);
          if (holiday != null) {
            holidays.add(holiday);
          } else {
            skippedEvents++;
          }
        }
        i++;
      }

      return IcsParseResult(
        holidays: holidays,
        calendarName: calendarName,
        totalEvents: totalEvents,
        skippedEvents: skippedEvents,
      );
    } catch (e, stackTrace) {
      debugPrint('[IcsParser] Parse error: $e');
      debugPrint('[IcsParser] Stack trace: $stackTrace');
      return IcsParseResult(
        holidays: [],
        totalEvents: 0,
        skippedEvents: 0,
        error: 'Failed to parse ICS file: $e',
      );
    }
  }

  /// Parse ICS content and extract as Todo objects (for imported calendar events)
  static IcsParseResultTodos parseTodos(
    String icsContent, {
    required String sourceCalendarName,
  }) {
    try {
      final todos = <Todo>[];
      String? calendarName;
      int totalEvents = 0;
      int skippedEvents = 0;

      final normalizedContent = _unfoldLines(icsContent);
      final lines = normalizedContent.split('\n');

      // Extract calendar name from X-WR-CALNAME if present
      for (final line in lines) {
        if (line.startsWith('X-WR-CALNAME:')) {
          calendarName = line.substring('X-WR-CALNAME:'.length).trim();
          break;
        }
      }

      // Get color for this calendar
      final calendarColor = ImportedCalendarColors.getColorForCalendarName(
        sourceCalendarName,
      );

      // Find and parse all VEVENT blocks
      int i = 0;
      while (i < lines.length) {
        if (lines[i].trim() == 'BEGIN:VEVENT') {
          totalEvents++;
          final eventLines = <String>[];
          i++;

          while (i < lines.length && lines[i].trim() != 'END:VEVENT') {
            eventLines.add(lines[i]);
            i++;
          }

          final todo = _parseEventAsTodo(
            eventLines,
            sourceCalendarName,
            calendarColor,
          );
          if (todo != null) {
            todos.add(todo);
          } else {
            skippedEvents++;
          }
        }
        i++;
      }

      return IcsParseResultTodos(
        todos: todos,
        calendarName: calendarName,
        totalEvents: totalEvents,
        skippedEvents: skippedEvents,
      );
    } catch (e, stackTrace) {
      debugPrint('[IcsParser] Parse todos error: $e');
      debugPrint('[IcsParser] Stack trace: $stackTrace');
      return IcsParseResultTodos(
        todos: [],
        totalEvents: 0,
        skippedEvents: 0,
        error: 'Failed to parse ICS file: $e',
      );
    }
  }

  /// Parse a single VEVENT block into a Todo object
  static Todo? _parseEventAsTodo(
    List<String> eventLines,
    String sourceCalendarName,
    int calendarColor,
  ) {
    String? summary;
    String? description;
    DateTime? dtStart;
    DateTime? dtEnd;
    bool isAllDay = false;

    for (final line in eventLines) {
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('SUMMARY')) {
        summary = _extractValue(trimmedLine);
      } else if (trimmedLine.startsWith('DESCRIPTION')) {
        description = _extractValue(trimmedLine);
        description = _unescapeText(description);
      } else if (trimmedLine.startsWith('DTSTART')) {
        isAllDay = trimmedLine.contains('VALUE=DATE');
        dtStart = _parseDate(trimmedLine);
      } else if (trimmedLine.startsWith('DTEND')) {
        if (trimmedLine.contains('VALUE=DATE')) isAllDay = true;
        dtEnd = _parseDate(trimmedLine);
      }
    }

    // Must have at least a summary and start date
    if (summary == null || dtStart == null) {
      return null;
    }

    // Additional check: if both dates have no time component, it's all-day
    if (!isAllDay &&
        dtStart.hour == 0 &&
        dtStart.minute == 0 &&
        dtStart.second == 0) {
      if (dtEnd != null &&
          dtEnd.hour == 0 &&
          dtEnd.minute == 0 &&
          dtEnd.second == 0) {
        isAllDay = true;
      }
    }

    // For all-day events, DTEND is exclusive (next day), so subtract 1 day
    DateTime? startDateForSpan;
    if (isAllDay && dtEnd != null) {
      dtEnd = dtEnd.subtract(const Duration(days: 1));
      final dtStartDay = DateTime(dtStart.year, dtStart.month, dtStart.day);
      final dtEndDay = DateTime(dtEnd.year, dtEnd.month, dtEnd.day);
      if (!dtStartDay.isAtSameMomentAs(dtEndDay)) {
        // Multi-day event: startDate = dtStart, dueDate = dtEnd
        startDateForSpan = dtStart;
        dtStart = dtEnd; // dueDate becomes the end date
      }
      // Single day event: no startDate needed
    }

    summary = _unescapeText(summary);

    return Todo(
      text: summary,
      dueDate: dtStart,
      startDate: startDateForSpan,
      notes: description ?? '',
      sourceCalendarColor: calendarColor,
      sourceCalendarName: sourceCalendarName,
      priority: 'none',
    );
  }

  /// Unfold lines according to RFC 5545 (lines starting with space/tab are continuations)
  static String _unfoldLines(String content) {
    // Normalize different line endings to \n
    var normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Unfold continuation lines (lines starting with space or tab)
    normalized = normalized.replaceAllMapped(RegExp(r'\n[ \t]'), (match) => '');

    return normalized;
  }

  /// Parse a single VEVENT block into a Holiday object
  static Holiday? _parseEvent(List<String> eventLines, String sourceCalendar) {
    String? summary;
    String? description;
    String? uid;
    DateTime? dtStart;
    DateTime? dtEnd;
    bool isAllDay = false;

    for (final line in eventLines) {
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('SUMMARY')) {
        summary = _extractValue(trimmedLine);
      } else if (trimmedLine.startsWith('DESCRIPTION')) {
        description = _extractValue(trimmedLine);
        // Clean up escaped characters in description
        description = _unescapeText(description);
      } else if (trimmedLine.startsWith('UID')) {
        uid = _extractValue(trimmedLine);
      } else if (trimmedLine.startsWith('DTSTART')) {
        isAllDay = trimmedLine.contains('VALUE=DATE');
        dtStart = _parseDate(trimmedLine);
      } else if (trimmedLine.startsWith('DTEND')) {
        // DTEND might also have VALUE=DATE flag
        if (trimmedLine.contains('VALUE=DATE')) isAllDay = true;
        dtEnd = _parseDate(trimmedLine);
      }
    }

    // Must have at least a summary and start date
    if (summary == null || dtStart == null) {
      return null;
    }

    // Additional check: if both dates have no time component, it's all-day
    if (!isAllDay &&
        dtStart.hour == 0 &&
        dtStart.minute == 0 &&
        dtStart.second == 0) {
      if (dtEnd != null &&
          dtEnd.hour == 0 &&
          dtEnd.minute == 0 &&
          dtEnd.second == 0) {
        isAllDay = true;
      }
    }

    // For all-day events, DTEND is exclusive (next day), so subtract 1 day
    if (isAllDay && dtEnd != null) {
      dtEnd = dtEnd.subtract(const Duration(days: 1));
      // If end date equals start date after adjustment, don't store endDate
      final dtStartDay = DateTime(dtStart.year, dtStart.month, dtStart.day);
      final dtEndDay = DateTime(dtEnd.year, dtEnd.month, dtEnd.day);
      if (dtStartDay.isAtSameMomentAs(dtEndDay)) {
        dtEnd = null;
      }
    }

    // Clean up summary
    summary = _unescapeText(summary);

    return Holiday(
      name: summary,
      date: dtStart,
      description: description ?? '',
      sourceCalendar: sourceCalendar,
      endDate: dtEnd,
      uid: uid ?? '',
    );
  }

  /// Extract value from a property line (handles parameters like VALUE=DATE)
  static String _extractValue(String line) {
    // Find the colon that separates property name from value
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) return '';
    return line.substring(colonIndex + 1).trim();
  }

  /// Parse date from DTSTART or DTEND line
  static DateTime? _parseDate(String line) {
    try {
      final value = _extractValue(line);
      if (value.isEmpty) return null;

      // Check if it's a date-only value (YYYYMMDD) or datetime (YYYYMMDDTHHMMSS)
      if (value.length == 8) {
        // Date only: YYYYMMDD
        return DateTime(
          int.parse(value.substring(0, 4)),
          int.parse(value.substring(4, 6)),
          int.parse(value.substring(6, 8)),
        );
      } else if (value.length >= 15) {
        // DateTime: YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ
        final dateStr = value.replaceAll('Z', '');
        return DateTime(
          int.parse(dateStr.substring(0, 4)),
          int.parse(dateStr.substring(4, 6)),
          int.parse(dateStr.substring(6, 8)),
          int.parse(dateStr.substring(9, 11)),
          int.parse(dateStr.substring(11, 13)),
          int.parse(dateStr.substring(13, 15)),
        );
      }
      return null;
    } catch (e) {
      debugPrint('[IcsParser] Failed to parse date: $line - $e');
      return null;
    }
  }

  /// Unescape text according to RFC 5545 and decode HTML entities
  static String _unescapeText(String text) {
    // First handle RFC 5545 backslash escapes
    var result = text
        .replaceAll(r"\'", "'")
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', '\\');

    // Then decode common HTML entities
    result = result
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&#8217;', "'") // Right single quotation mark
        .replaceAll('&#8216;', "'") // Left single quotation mark
        .replaceAll('&#8220;', '"') // Left double quotation mark
        .replaceAll('&#8221;', '"') // Right double quotation mark
        .replaceAll('&apos;', "'");

    return result;
  }
}
