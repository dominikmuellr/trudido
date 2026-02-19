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

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'holiday.g.dart';

/// Represents a holiday event imported from an ICS calendar file
@HiveType(typeId: 8)
class Holiday extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime date;

  @HiveField(3, defaultValue: '')
  String description;

  @HiveField(4)
  String sourceCalendar; // Name of the imported calendar

  @HiveField(5, defaultValue: false)
  bool isHidden; // Allow users to hide duplicate/unwanted holidays

  @HiveField(6)
  DateTime? endDate; // For multi-day holidays

  @HiveField(7, defaultValue: '')
  String uid; // Original UID from ICS file for deduplication

  Holiday({
    String? id,
    required this.name,
    required this.date,
    this.description = '',
    required this.sourceCalendar,
    this.isHidden = false,
    this.endDate,
    this.uid = '',
  }) : id = id ?? const Uuid().v4();

  /// Creates a copy of this holiday with updated fields
  Holiday copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? description,
    String? sourceCalendar,
    bool? isHidden,
    DateTime? endDate,
    bool clearEndDate = false,
    String? uid,
  }) {
    return Holiday(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      description: description ?? this.description,
      sourceCalendar: sourceCalendar ?? this.sourceCalendar,
      isHidden: isHidden ?? this.isHidden,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      uid: uid ?? this.uid,
    );
  }

  /// Check if this holiday occurs on a specific date
  bool occursOn(DateTime checkDate) {
    final checkDateOnly = DateTime(
      checkDate.year,
      checkDate.month,
      checkDate.day,
    );
    final startDateOnly = DateTime(date.year, date.month, date.day);

    if (endDate == null) {
      return checkDateOnly == startDateOnly;
    }

    final endDateOnly = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !checkDateOnly.isBefore(startDateOnly) &&
        !checkDateOnly.isAfter(endDateOnly);
  }

  /// Check if this is a duplicate of another holiday (same date and name)
  bool isDuplicateOf(Holiday other) {
    if (id == other.id) return false; // Same holiday
    final sameDate =
        date.year == other.date.year &&
        date.month == other.date.month &&
        date.day == other.date.day;
    final sameName =
        name.toLowerCase().trim() == other.name.toLowerCase().trim();
    return sameDate && sameName;
  }

  @override
  String toString() =>
      'Holiday(name: $name, date: $date, source: $sourceCalendar)';
}
