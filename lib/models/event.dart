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

import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';
import '../utils/isar_id.dart';

part 'event.g.dart';

/// Represents a calendar event, separate from tasks.
/// Events have full datetime support (start/end times) and can span
/// single or multiple days.
@collection
class Event {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  String id;

  String text;

  bool isCompleted;

  DateTime? createdAt;

  DateTime startDateTime;

  DateTime endDateTime;

  String priority;

  List<String> tags;

  DateTime? completedAt;

  String? notes;

  String? folderId;

  List<int> reminderOffsetsMinutes;

  String repeatType; // 'none', 'daily', 'weekly', 'monthly', 'yearly', 'custom'

  int? repeatInterval;

  List<int>? repeatDays; // e.g., [1, 3, 5] for Mon/Wed/Fri (1=Mon, 7=Sun)

  DateTime? repeatEndDate;

  String? parentRecurringEventId;

  int? sourceCalendarColor;

  String? sourceCalendarName;

  bool isDeleted;

  DateTime? deletedAt;

  int? color; // Custom event color

  String uid; // For ICS / calendar sync deduplication

  String? location;

  Event({
    String id = '',
    required this.text,
    this.isCompleted = false,
    DateTime? createdAt,
    required this.startDateTime,
    required this.endDateTime,
    this.priority = 'none',
    this.tags = const [],
    this.completedAt,
    this.notes,
    this.folderId,
    this.reminderOffsetsMinutes = const [0],
    this.repeatType = 'none',
    this.repeatInterval,
    this.repeatDays,
    this.repeatEndDate,
    this.parentRecurringEventId,
    this.sourceCalendarColor,
    this.sourceCalendarName,
    this.isDeleted = false,
    this.deletedAt,
    this.color,
    this.uid = '',
    this.location,
  }) : id = id.isEmpty ? const Uuid().v4() : id,
       createdAt = createdAt ?? DateTime.now();

  Event copyWith({
    String? id,
    String? text,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? priority,
    List<String>? tags,
    DateTime? completedAt,
    String? notes,
    String? folderId,
    List<int>? reminderOffsetsMinutes,
    String? repeatType,
    int? repeatInterval,
    List<int>? repeatDays,
    DateTime? repeatEndDate,
    String? parentRecurringEventId,
    int? sourceCalendarColor,
    String? sourceCalendarName,
    bool? isDeleted,
    DateTime? deletedAt,
    int? color,
    String? uid,
    String? location,
  }) {
    return Event(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      folderId: folderId ?? this.folderId,
      reminderOffsetsMinutes:
          reminderOffsetsMinutes ?? this.reminderOffsetsMinutes,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatEndDate: repeatEndDate ?? this.repeatEndDate,
      parentRecurringEventId:
          parentRecurringEventId ?? this.parentRecurringEventId,
      sourceCalendarColor: sourceCalendarColor ?? this.sourceCalendarColor,
      sourceCalendarName: sourceCalendarName ?? this.sourceCalendarName,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      color: color ?? this.color,
      uid: uid ?? this.uid,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'startDateTime': startDateTime.toIso8601String(),
      'endDateTime': endDateTime.toIso8601String(),
      'priority': priority,
      'tags': tags,
      'completedAt': completedAt?.toIso8601String(),
      'notes': notes,
      'folderId': folderId,
      'reminderOffsetsMinutes': reminderOffsetsMinutes,
      'repeatType': repeatType,
      'repeatInterval': repeatInterval,
      'repeatDays': repeatDays,
      'repeatEndDate': repeatEndDate?.toIso8601String(),
      'parentRecurringEventId': parentRecurringEventId,
      'sourceCalendarColor': sourceCalendarColor,
      'sourceCalendarName': sourceCalendarName,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'color': color,
      'uid': uid,
      'location': location,
    };
  }

  static Event fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      text: json['text'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      startDateTime: DateTime.parse(json['startDateTime']),
      endDateTime: DateTime.parse(json['endDateTime']),
      priority: json['priority'] ?? 'none',
      tags: List<String>.from(json['tags'] ?? []),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      notes: json['notes'],
      folderId: json['folderId'],
      reminderOffsetsMinutes: List<int>.from(
        json['reminderOffsetsMinutes'] ?? [],
      ),
      repeatType: json['repeatType'] ?? 'none',
      repeatInterval: json['repeatInterval'],
      repeatDays: json['repeatDays'] != null
          ? List<int>.from(json['repeatDays'])
          : null,
      repeatEndDate: json['repeatEndDate'] != null
          ? DateTime.parse(json['repeatEndDate'])
          : null,
      parentRecurringEventId: json['parentRecurringEventId'],
      sourceCalendarColor: json['sourceCalendarColor'],
      sourceCalendarName: json['sourceCalendarName'],
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'])
          : null,
      color: json['color'],
      uid: json['uid'] ?? '',
      location: json['location'],
    );
  }

  // Helper methods

  /// Whether this event spans multiple days.
  @ignore
  bool get isMultiDay {
    final s = DateTime(
      startDateTime.year,
      startDateTime.month,
      startDateTime.day,
    );
    final e = DateTime(endDateTime.year, endDateTime.month, endDateTime.day);
    return e.isAfter(s);
  }

  /// Whether this event is an all-day event (starts at midnight and ends at midnight).
  @ignore
  bool get isAllDay {
    return startDateTime.hour == 0 &&
        startDateTime.minute == 0 &&
        endDateTime.hour == 0 &&
        endDateTime.minute == 0;
  }

  /// Check if this event occurs on a specific date.
  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(
      startDateTime.year,
      startDateTime.month,
      startDateTime.day,
    );
    final e = DateTime(endDateTime.year, endDateTime.month, endDateTime.day);
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) &&
        (d.isAtSameMomentAs(e) || d.isBefore(e));
  }

  /// Whether the event has already ended.
  bool hasEndedAt([DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    return currentTime.isAfter(endDateTime);
  }

  @ignore
  bool get hasEnded => hasEndedAt();

  /// Check if this event is recurring.
  @ignore
  bool get isRecurring => repeatType != 'none';

  /// Duration of the event.
  @ignore
  Duration get duration => endDateTime.difference(startDateTime);

  @override
  String toString() {
    return 'Event(id: $id, text: $text, start: $startDateTime, end: $endDateTime, isCompleted: $isCompleted, priority: $priority, folderId: $folderId, repeatType: $repeatType)';
  }
}
