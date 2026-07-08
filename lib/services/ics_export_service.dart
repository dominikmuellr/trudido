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

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event.dart';
import '../models/todo.dart';

/// Service for exporting Events and Tasks as ICS (iCalendar) files.
class IcsExportService {
  /// Format a DateTime to ICS UTC format: 20260309T140000Z
  static String _formatDateTimeUtc(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}'
        'T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}'
        'Z';
  }

  /// Format a DateTime to ICS all-day format: 20260309
  static String _formatDateOnly(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  /// Escape text for ICS format (fold long lines, escape special chars).
  static String _escapeIcsText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  /// Build ICS VEVENT block for an Event.
  static String _eventToVEvent(Event event) {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VEVENT');
    buf.writeln('UID:${event.uid.isNotEmpty ? event.uid : event.id}@trudido');
    buf.writeln(
      'DTSTAMP:${_formatDateTimeUtc(event.createdAt ?? DateTime.now())}',
    );

    if (event.isAllDay) {
      buf.writeln('DTSTART;VALUE=DATE:${_formatDateOnly(event.startDateTime)}');
      // ICS all-day end date is exclusive, so add one day
      final endPlusOne = event.endDateTime.add(const Duration(days: 1));
      buf.writeln('DTEND;VALUE=DATE:${_formatDateOnly(endPlusOne)}');
    } else {
      buf.writeln('DTSTART:${_formatDateTimeUtc(event.startDateTime)}');
      buf.writeln('DTEND:${_formatDateTimeUtc(event.endDateTime)}');
    }

    buf.writeln('SUMMARY:${_escapeIcsText(event.text)}');

    if (event.notes != null && event.notes!.isNotEmpty) {
      buf.writeln('DESCRIPTION:${_escapeIcsText(event.notes!)}');
    }

    if (event.location != null && event.location!.isNotEmpty) {
      buf.writeln('LOCATION:${_escapeIcsText(event.location!)}');
    }

    if (event.isCompleted) {
      buf.writeln('STATUS:COMPLETED');
    } else {
      buf.writeln('STATUS:CONFIRMED');
    }

    // Add priority mapping: ICS uses 1-9 (1=high, 5=medium, 9=low)
    switch (event.priority) {
      case 'high':
        buf.writeln('PRIORITY:1');
        break;
      case 'medium':
        buf.writeln('PRIORITY:5');
        break;
      case 'low':
        buf.writeln('PRIORITY:9');
        break;
    }

    // Add reminders as VALARM
    for (final offset in event.reminderOffsetsMinutes) {
      if (offset >= 0) {
        buf.writeln('BEGIN:VALARM');
        buf.writeln('TRIGGER:-PT${offset}M');
        buf.writeln('ACTION:DISPLAY');
        buf.writeln('DESCRIPTION:${_escapeIcsText(event.text)}');
        buf.writeln('END:VALARM');
      }
    }

    // Add recurrence rule
    final rrule = _buildRRule(
      event.repeatType,
      event.repeatInterval,
      event.repeatDays,
      event.repeatEndDate,
    );
    if (rrule != null) {
      buf.writeln(rrule);
    }

    buf.writeln('END:VEVENT');
    return buf.toString();
  }

  /// Build ICS VEVENT block for a Task (limited — tasks don't have dates).
  /// Tasks with dueDate are exported; tasks without dates are skipped.
  static String? _taskToVEvent(Todo task) {
    if (task.dueDate == null) return null;

    final buf = StringBuffer();
    buf.writeln('BEGIN:VEVENT');
    buf.writeln('UID:${task.id}@trudido');
    buf.writeln(
      'DTSTAMP:${_formatDateTimeUtc(task.createdAt ?? DateTime.now())}',
    );

    final isAllDay =
        task.dueDate!.hour == 0 &&
        task.dueDate!.minute == 0 &&
        task.dueDate!.second == 0;

    if (isAllDay) {
      if (task.startDate != null) {
        buf.writeln('DTSTART;VALUE=DATE:${_formatDateOnly(task.startDate!)}');
      } else {
        buf.writeln('DTSTART;VALUE=DATE:${_formatDateOnly(task.dueDate!)}');
      }
      final endPlusOne = task.dueDate!.add(const Duration(days: 1));
      buf.writeln('DTEND;VALUE=DATE:${_formatDateOnly(endPlusOne)}');
    } else {
      final start = task.startDate ?? task.dueDate!;
      buf.writeln('DTSTART:${_formatDateTimeUtc(start)}');
      buf.writeln('DTEND:${_formatDateTimeUtc(task.dueDate!)}');
    }

    buf.writeln('SUMMARY:${_escapeIcsText(task.text)}');

    if (task.notes != null && task.notes!.isNotEmpty) {
      buf.writeln('DESCRIPTION:${_escapeIcsText(task.notes!)}');
    }

    if (task.isCompleted) {
      buf.writeln('STATUS:COMPLETED');
    } else {
      buf.writeln('STATUS:CONFIRMED');
    }

    switch (task.priority) {
      case 'high':
        buf.writeln('PRIORITY:1');
        break;
      case 'medium':
        buf.writeln('PRIORITY:5');
        break;
      case 'low':
        buf.writeln('PRIORITY:9');
        break;
    }

    for (final offset in task.reminderOffsetsMinutes) {
      if (offset >= 0) {
        buf.writeln('BEGIN:VALARM');
        buf.writeln('TRIGGER:-PT${offset}M');
        buf.writeln('ACTION:DISPLAY');
        buf.writeln('DESCRIPTION:${_escapeIcsText(task.text)}');
        buf.writeln('END:VALARM');
      }
    }

    final rrule = _buildRRule(
      task.repeatType,
      task.repeatInterval,
      task.repeatDays,
      task.repeatEndDate,
    );
    if (rrule != null) {
      buf.writeln(rrule);
    }

    buf.writeln('END:VEVENT');
    return buf.toString();
  }

  /// Build an RRULE string from recurrence parameters.
  static String? _buildRRule(
    String repeatType,
    int? repeatInterval,
    List<int>? repeatDays,
    DateTime? repeatEndDate,
  ) {
    if (repeatType == 'none') return null;

    final parts = <String>[];

    switch (repeatType) {
      case 'daily':
        parts.add('FREQ=DAILY');
        if (repeatInterval != null && repeatInterval > 1) {
          parts.add('INTERVAL=$repeatInterval');
        }
        break;
      case 'weekly':
        parts.add('FREQ=WEEKLY');
        if (repeatInterval != null && repeatInterval > 1) {
          parts.add('INTERVAL=$repeatInterval');
        }
        break;
      case 'monthly':
        parts.add('FREQ=MONTHLY');
        if (repeatInterval != null && repeatInterval > 1) {
          parts.add('INTERVAL=$repeatInterval');
        }
        break;
      case 'custom':
        if (repeatDays != null && repeatDays.isNotEmpty) {
          parts.add('FREQ=WEEKLY');
          if (repeatInterval != null && repeatInterval > 1) {
            parts.add('INTERVAL=$repeatInterval');
          }
          // Convert day numbers (1=Mon, 7=Sun) to ICS day codes
          const dayMap = {
            1: 'MO',
            2: 'TU',
            3: 'WE',
            4: 'TH',
            5: 'FR',
            6: 'SA',
            7: 'SU',
          };
          final days = repeatDays
              .map((d) => dayMap[d])
              .where((d) => d != null)
              .join(',');
          if (days.isNotEmpty) {
            parts.add('BYDAY=$days');
          }
        } else {
          parts.add('FREQ=DAILY');
          if (repeatInterval != null && repeatInterval > 1) {
            parts.add('INTERVAL=$repeatInterval');
          }
        }
        break;
      default:
        return null;
    }

    if (repeatEndDate != null) {
      parts.add('UNTIL=${_formatDateTimeUtc(repeatEndDate)}');
    }

    return 'RRULE:${parts.join(';')}';
  }

  /// Generate a complete ICS file content from a list of events.
  static String generateEventsIcs(List<Event> events) {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//Trudido//Events//EN');
    buf.writeln('CALSCALE:GREGORIAN');
    buf.writeln('METHOD:PUBLISH');

    for (final event in events) {
      buf.write(_eventToVEvent(event));
    }

    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  /// Generate a complete ICS file content from a list of tasks.
  static String generateTasksIcs(List<Todo> tasks) {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//Trudido//Tasks//EN');
    buf.writeln('CALSCALE:GREGORIAN');
    buf.writeln('METHOD:PUBLISH');

    for (final task in tasks) {
      final vevent = _taskToVEvent(task);
      if (vevent != null) {
        buf.write(vevent);
      }
    }

    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  /// Export events as an .ics file and share it.
  static Future<void> exportAndShareEvents(
    List<Event> events, {
    String filename = 'trudido_events.ics',
  }) async {
    final icsContent = generateEventsIcs(events);
    await _shareIcsFile(icsContent, filename);
  }

  /// Export tasks as an .ics file and share it.
  static Future<void> exportAndShareTasks(
    List<Todo> tasks, {
    String filename = 'trudido_tasks.ics',
  }) async {
    final icsContent = generateTasksIcs(tasks);
    await _shareIcsFile(icsContent, filename);
  }

  static Future<void> _shareIcsFile(String content, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/calendar')]),
    );
  }
}
