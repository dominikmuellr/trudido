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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/holiday.dart';
import '../models/todo.dart';
import '../repositories/holiday_repository.dart';
import '../utils/ics_parser.dart';
import 'app_providers.dart';

/// Holiday repository provider (singleton)
final holidayRepositoryProvider = Provider<HolidayRepository>((ref) {
  return HolidayRepository();
});

/// State for holiday list with notifier
class HolidayNotifier extends StateNotifier<List<Holiday>> {
  final HolidayRepository repository;

  HolidayNotifier(this.repository) : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      await repository.init();
      // Fix existing single-day holidays that have wrong endDate
      await _fixSingleDayHolidays();
      state = await repository.getAllHolidays();
    } catch (e) {
      debugPrint('[HolidayNotifier] Failed to load holidays: $e');
    }
  }

  /// Fix single-day holidays that have endDate set to the next day
  Future<void> _fixSingleDayHolidays() async {
    try {
      final allHolidays = await repository.getAllHolidays();
      int fixedCount = 0;

      for (final holiday in allHolidays) {
        if (holiday.endDate != null) {
          final startDay = DateTime(
            holiday.date.year,
            holiday.date.month,
            holiday.date.day,
          );
          final endDay = DateTime(
            holiday.endDate!.year,
            holiday.endDate!.month,
            holiday.endDate!.day,
          );

          // If endDate is same day or exactly 1 day after startDate, it's a single-day event
          // imported with old parser (ICS exclusive end dates)
          if (startDay.isAtSameMomentAs(endDay) ||
              endDay.difference(startDay).inDays == 1) {
            debugPrint(
              '[HolidayNotifier] Fixing holiday: ${holiday.name}, date: ${holiday.date}, endDate: ${holiday.endDate}',
            );
            final fixed = holiday.copyWith(clearEndDate: true);
            await repository.updateHoliday(fixed);
            fixedCount++;
          }
        }
      }

      if (fixedCount > 0) {
        debugPrint('[HolidayNotifier] Fixed $fixedCount single-day holidays');
      }
    } catch (e) {
      debugPrint('[HolidayNotifier] Failed to fix single-day holidays: $e');
    }
  }

  Future<void> refresh() async {
    state = await repository.getAllHolidays();
  }

  /// Import holidays from an ICS file
  Future<IcsParseResult> importFromFile() async {
    try {
      // Pick .ics file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
      );

      if (result == null || result.files.isEmpty) {
        return IcsParseResult(
          holidays: [],
          totalEvents: 0,
          skippedEvents: 0,
          error: 'No file selected',
        );
      }

      final file = result.files.first;
      String content;

      if (file.bytes != null) {
        // Web or memory-based file
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        // File path available
        content = await File(file.path!).readAsString();
      } else {
        return IcsParseResult(
          holidays: [],
          totalEvents: 0,
          skippedEvents: 0,
          error: 'Could not read file',
        );
      }

      // Use filename (without extension) as source calendar name
      final sourceName = file.name.replaceAll('.ics', '').replaceAll('_', ' ');

      // Parse ICS content
      final parseResult = IcsParser.parse(content, sourceCalendar: sourceName);

      if (parseResult.success) {
        // Add holidays to repository
        await repository.addHolidays(parseResult.holidays);
        // Fix any single-day holidays that were just imported with wrong endDate
        await _fixSingleDayHolidays();
        await refresh();
      }

      return parseResult;
    } catch (e, stackTrace) {
      debugPrint('[HolidayNotifier] Import error: $e');
      debugPrint('[HolidayNotifier] Stack trace: $stackTrace');
      return IcsParseResult(
        holidays: [],
        totalEvents: 0,
        skippedEvents: 0,
        error: 'Import failed: $e',
      );
    }
  }

  /// Import holidays from ICS content with custom source name
  Future<IcsParseResult> importFromContent(
    String content,
    String sourceName,
  ) async {
    try {
      final parseResult = IcsParser.parse(content, sourceCalendar: sourceName);

      if (parseResult.success) {
        await repository.addHolidays(parseResult.holidays);
        await refresh();
      }

      return parseResult;
    } catch (e) {
      debugPrint('[HolidayNotifier] Import error: $e');
      return IcsParseResult(
        holidays: [],
        totalEvents: 0,
        skippedEvents: 0,
        error: 'Import failed: $e',
      );
    }
  }

  /// Toggle hidden status
  Future<void> toggleHidden(String holidayId) async {
    await repository.toggleHidden(holidayId);
    await refresh();
  }

  /// Delete all holidays from a source calendar
  Future<int> deleteSource(String sourceCalendar) async {
    final count = await repository.deleteBySource(sourceCalendar);
    await refresh();
    return count;
  }

  /// Delete individual holiday (move to bin equivalent)
  Future<void> deleteHoliday(String holidayId) async {
    await repository.deleteHoliday(holidayId);
    await refresh();
  }

  /// Clear all holidays
  Future<void> clearAll() async {
    await repository.clearAll();
    await refresh();
  }
}

/// Main holidays provider
final holidaysProvider = StateNotifierProvider<HolidayNotifier, List<Holiday>>((
  ref,
) {
  final repository = ref.watch(holidayRepositoryProvider);
  return HolidayNotifier(repository);
});

/// Visible holidays only (not hidden)
final visibleHolidaysProvider = Provider<List<Holiday>>((ref) {
  final all = ref.watch(holidaysProvider);
  return all.where((h) => !h.isHidden).toList();
});

/// List of imported calendar source names
final holidaySourcesProvider = Provider<List<String>>((ref) {
  final all = ref.watch(holidaysProvider);
  final sources = all.map((h) => h.sourceCalendar).toSet().toList();
  sources.sort();
  return sources;
});

/// Count of holidays per source
final holidayCountBySourceProvider = Provider<Map<String, int>>((ref) {
  final all = ref.watch(holidaysProvider);
  final counts = <String, int>{};
  for (final holiday in all) {
    counts[holiday.sourceCalendar] = (counts[holiday.sourceCalendar] ?? 0) + 1;
  }
  return counts;
});

/// Holidays for a specific date (provider family)
final holidaysForDateProvider = Provider.family<List<Holiday>, DateTime>((
  ref,
  date,
) {
  final visible = ref.watch(visibleHolidaysProvider);
  return visible.where((h) => h.occursOn(date)).toList();
});

/// Check if holidays feature is enabled (has any imported calendars)
final hasHolidaysProvider = Provider<bool>((ref) {
  final all = ref.watch(holidaysProvider);
  return all.isNotEmpty;
});

/// Provider to show/hide holidays in calendar (user preference)
final showHolidaysInCalendarProvider = StateProvider<bool>((ref) => true);

// ============================================================================
// Imported Events Providers (for ICS → Tasks refactor)
// ============================================================================

/// Filter todos to get only imported calendar events
final importedTasksProvider = Provider<List<Todo>>((ref) {
  final all = ref.watch(tasksProvider);
  return all
      .where(
        (t) => t.sourceCalendarName != null && t.sourceCalendarName!.isNotEmpty,
      )
      .toList();
});

/// Get list of imported calendar sources
final importedCalendarSourcesProvider = Provider<List<String>>((ref) {
  final imported = ref.watch(importedTasksProvider);
  final sources = imported
      .map((t) => t.sourceCalendarName ?? '')
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();
  sources.sort();
  return sources;
});

/// Count of imported tasks per source
final importedTaskCountBySourceProvider = Provider<Map<String, int>>((ref) {
  final imported = ref.watch(importedTasksProvider);
  final counts = <String, int>{};
  for (final task in imported) {
    if (task.sourceCalendarName != null) {
      final source = task.sourceCalendarName!;
      counts[source] = (counts[source] ?? 0) + 1;
    }
  }
  return counts;
});

/// Show/hide imported calendar events in calendar view
final showImportedEventsInCalendarProvider = StateProvider<bool>((ref) => true);
