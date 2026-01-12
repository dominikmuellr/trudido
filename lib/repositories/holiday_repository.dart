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

import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/holiday.dart';

/// Repository for managing imported holiday calendars
class HolidayRepository {
  static const String _holidaysBoxName = 'holidays';
  Box<Holiday>? _holidaysBox;

  /// Initialize the repository with Hive box
  Future<void> init() async {
    if (_holidaysBox != null && _holidaysBox!.isOpen) return;
    _holidaysBox = await Hive.openBox<Holiday>(_holidaysBoxName);
    debugPrint(
      '[HolidayRepository] Initialized with ${_holidaysBox!.length} holidays',
    );
  }

  /// Ensure box is initialized
  Future<void> _ensureInit() async {
    if (_holidaysBox == null || !_holidaysBox!.isOpen) {
      await init();
    }
  }

  /// Get all holidays
  Future<List<Holiday>> getAllHolidays() async {
    await _ensureInit();
    return _holidaysBox!.values.toList();
  }

  /// Get visible holidays only (not hidden)
  Future<List<Holiday>> getVisibleHolidays() async {
    await _ensureInit();
    return _holidaysBox!.values.where((h) => !h.isHidden).toList();
  }

  /// Get holidays for a specific date
  Future<List<Holiday>> getHolidaysForDate(DateTime date) async {
    await _ensureInit();
    return _holidaysBox!.values
        .where((h) => !h.isHidden && h.occursOn(date))
        .toList();
  }

  /// Get holidays in a date range
  Future<List<Holiday>> getHolidaysInRange(DateTime start, DateTime end) async {
    await _ensureInit();
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    return _holidaysBox!.values.where((h) {
      if (h.isHidden) return false;
      final holidayDate = DateTime(h.date.year, h.date.month, h.date.day);
      return !holidayDate.isBefore(startDate) && !holidayDate.isAfter(endDate);
    }).toList();
  }

  /// Get list of all imported calendar sources
  Future<List<String>> getCalendarSources() async {
    await _ensureInit();
    final sources = _holidaysBox!.values
        .map((h) => h.sourceCalendar)
        .toSet()
        .toList();
    sources.sort();
    return sources;
  }

  /// Get holidays from a specific source calendar
  Future<List<Holiday>> getHolidaysBySource(String sourceCalendar) async {
    await _ensureInit();
    return _holidaysBox!.values
        .where((h) => h.sourceCalendar == sourceCalendar)
        .toList();
  }

  /// Add multiple holidays (from import)
  Future<int> addHolidays(List<Holiday> holidays) async {
    await _ensureInit();
    int addedCount = 0;

    for (final holiday in holidays) {
      // Check for duplicates by UID within same source
      final existingByUid = _holidaysBox!.values
          .where(
            (h) =>
                h.uid.isNotEmpty &&
                h.uid == holiday.uid &&
                h.sourceCalendar == holiday.sourceCalendar,
          )
          .toList();

      if (existingByUid.isEmpty) {
        await _holidaysBox!.put(holiday.id, holiday);
        addedCount++;
      } else {
        // Update existing holiday
        final existing = existingByUid.first;
        final updated = holiday.copyWith(
          id: existing.id,
          isHidden: existing.isHidden, // Preserve hidden status
        );
        await _holidaysBox!.put(existing.id, updated);
      }
    }

    debugPrint('[HolidayRepository] Added $addedCount new holidays');
    return addedCount;
  }

  /// Toggle hidden status of a holiday
  Future<void> toggleHidden(String holidayId) async {
    await _ensureInit();
    final holiday = _holidaysBox!.get(holidayId);
    if (holiday != null) {
      final updated = holiday.copyWith(isHidden: !holiday.isHidden);
      await _holidaysBox!.put(holidayId, updated);
    }
  }

  /// Set hidden status of a holiday
  Future<void> setHidden(String holidayId, bool hidden) async {
    await _ensureInit();
    final holiday = _holidaysBox!.get(holidayId);
    if (holiday != null) {
      final updated = holiday.copyWith(isHidden: hidden);
      await _holidaysBox!.put(holidayId, updated);
    }
  }

  /// Delete all holidays from a specific source calendar
  Future<int> deleteBySource(String sourceCalendar) async {
    await _ensureInit();
    final toDelete = _holidaysBox!.values
        .where((h) => h.sourceCalendar == sourceCalendar)
        .map((h) => h.id)
        .toList();

    for (final id in toDelete) {
      await _holidaysBox!.delete(id);
    }

    debugPrint(
      '[HolidayRepository] Deleted ${toDelete.length} holidays from $sourceCalendar',
    );
    return toDelete.length;
  }

  /// Delete a single holiday
  Future<void> deleteHoliday(String holidayId) async {
    await _ensureInit();
    await _holidaysBox!.delete(holidayId);
  }

  /// Update an existing holiday
  Future<void> updateHoliday(Holiday holiday) async {
    await _ensureInit();
    await _holidaysBox!.put(holiday.id, holiday);
  }

  /// Clear all holidays
  Future<void> clearAll() async {
    await _ensureInit();
    await _holidaysBox!.clear();
    debugPrint('[HolidayRepository] Cleared all holidays');
  }

  /// Get count of holidays per source
  Future<Map<String, int>> getHolidayCountBySource() async {
    await _ensureInit();
    final counts = <String, int>{};
    for (final holiday in _holidaysBox!.values) {
      counts[holiday.sourceCalendar] =
          (counts[holiday.sourceCalendar] ?? 0) + 1;
    }
    return counts;
  }

  /// Find duplicate holidays (same name and date from different sources)
  Future<List<List<Holiday>>> findDuplicates() async {
    await _ensureInit();
    final holidays = _holidaysBox!.values.toList();
    final duplicateGroups = <String, List<Holiday>>{};

    for (final holiday in holidays) {
      final key =
          '${holiday.date.year}-${holiday.date.month}-${holiday.date.day}-${holiday.name.toLowerCase().trim()}';
      duplicateGroups.putIfAbsent(key, () => []).add(holiday);
    }

    return duplicateGroups.values.where((group) => group.length > 1).toList();
  }
}
