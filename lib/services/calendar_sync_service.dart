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

import 'dart:convert';
import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';

/// Represents a selected calendar for sync
class SelectedCalendar {
  final String id;
  final String name;
  final int color;
  final bool isForExport; // Whether to export tasks to this calendar
  final bool isForImport; // Whether to import events from this calendar

  const SelectedCalendar({
    required this.id,
    required this.name,
    required this.color,
    this.isForExport = true,
    this.isForImport = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'isForExport': isForExport,
    'isForImport': isForImport,
  };

  factory SelectedCalendar.fromJson(Map<String, dynamic> json) =>
      SelectedCalendar(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as int? ?? 0xFF2196F3,
        isForExport: json['isForExport'] as bool? ?? true,
        isForImport: json['isForImport'] as bool? ?? true,
      );

  SelectedCalendar copyWith({
    String? id,
    String? name,
    int? color,
    bool? isForExport,
    bool? isForImport,
  }) => SelectedCalendar(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    isForExport: isForExport ?? this.isForExport,
    isForImport: isForImport ?? this.isForImport,
  );
}

/// Service for syncing tasks with the device calendar
class CalendarSyncService {
  static final CalendarSyncService _instance = CalendarSyncService._internal();
  factory CalendarSyncService() => _instance;
  CalendarSyncService._internal();

  final DeviceCalendar _calendarPlugin = DeviceCalendar.instance;
  SharedPreferences? _prefs;

  // Preference keys
  static const String _keyCalendarSyncEnabled = 'calendar_sync_enabled';
  static const String _keySelectedCalendars =
      'calendar_sync_selected_calendars';
  static const String _keyPrimaryExportCalendarId =
      'calendar_sync_primary_export_id';
  static const String _keySyncCompletedTasks = 'calendar_sync_completed_tasks';
  static const String _keyTwoWaySyncEnabled = 'calendar_two_way_sync_enabled';
  static const String _keyAutoSyncOnStartup = 'calendar_auto_sync_on_startup';
  static const String _keyLastSyncTime = 'calendar_last_sync_time';
  static const String _keyEventMappingPrefix = 'calendar_event_mapping_';
  static const String _keyImportedEventPrefix = 'calendar_imported_event_';

  // Legacy keys for migration
  static const String _keySelectedCalendarId = 'calendar_sync_calendar_id';
  static const String _keySelectedCalendarName = 'calendar_sync_calendar_name';

  bool _isInitialized = false;

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _migrateFromSingleCalendar();
    _isInitialized = true;
  }

  Future<void> _migrateFromSingleCalendar() async {
    final oldId = _prefs?.getString(_keySelectedCalendarId);
    final oldName = _prefs?.getString(_keySelectedCalendarName);

    if (oldId != null && oldName != null) {
      final existingCalendars = selectedCalendars;
      if (existingCalendars.isEmpty) {
        // Migrate old single calendar to new format
        await addSelectedCalendar(
          SelectedCalendar(
            id: oldId,
            name: oldName,
            color: 0xFF2196F3,
            isForExport: true,
            isForImport: true,
          ),
        );
        await setPrimaryExportCalendar(oldId);
      }
      // Clean up old keys
      await _prefs?.remove(_keySelectedCalendarId);
      await _prefs?.remove(_keySelectedCalendarName);
    }
  }

  /// Check if calendar sync is enabled
  bool get isEnabled => _prefs?.getBool(_keyCalendarSyncEnabled) ?? false;

  /// Get selected calendars
  List<SelectedCalendar> get selectedCalendars {
    final json = _prefs?.getString(_keySelectedCalendars);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => SelectedCalendar.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get primary export calendar ID
  String? get primaryExportCalendarId =>
      _prefs?.getString(_keyPrimaryExportCalendarId);

  /// Get primary export calendar
  SelectedCalendar? get primaryExportCalendar {
    final id = primaryExportCalendarId;
    if (id == null) return null;
    return selectedCalendars.where((c) => c.id == id).firstOrNull;
  }

  /// Get calendars enabled for export
  List<SelectedCalendar> get exportCalendars =>
      selectedCalendars.where((c) => c.isForExport).toList();

  /// Get calendars enabled for import
  List<SelectedCalendar> get importCalendars =>
      selectedCalendars.where((c) => c.isForImport).toList();

  /// Check if completed tasks should be synced
  bool get syncCompletedTasks =>
      _prefs?.getBool(_keySyncCompletedTasks) ?? false;

  /// Check if two-way sync is enabled
  bool get twoWaySyncEnabled => _prefs?.getBool(_keyTwoWaySyncEnabled) ?? false;

  /// Check if auto-sync on startup is enabled
  bool get autoSyncOnStartup => _prefs?.getBool(_keyAutoSyncOnStartup) ?? false;

  /// Get last sync time
  DateTime? get lastSyncTime {
    final timestamp = _prefs?.getInt(_keyLastSyncTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Enable or disable calendar sync
  Future<void> setEnabled(bool value) async {
    await _prefs?.setBool(_keyCalendarSyncEnabled, value);
  }

  /// Add a calendar to the selected list
  Future<void> addSelectedCalendar(SelectedCalendar calendar) async {
    final current = selectedCalendars;
    if (!current.any((c) => c.id == calendar.id)) {
      current.add(calendar);
      await _saveSelectedCalendars(current);
      // If this is the first calendar, set it as primary export
      if (current.length == 1) {
        await setPrimaryExportCalendar(calendar.id);
      }
    }
  }

  /// Remove a calendar from the selected list
  Future<void> removeSelectedCalendar(String calendarId) async {
    final current = selectedCalendars;
    current.removeWhere((c) => c.id == calendarId);
    await _saveSelectedCalendars(current);
    // If we removed the primary export calendar, select the first one
    if (primaryExportCalendarId == calendarId && current.isNotEmpty) {
      await setPrimaryExportCalendar(current.first.id);
    } else if (current.isEmpty) {
      await _prefs?.remove(_keyPrimaryExportCalendarId);
    }
  }

  /// Update a selected calendar's settings
  Future<void> updateSelectedCalendar(SelectedCalendar calendar) async {
    final current = selectedCalendars;
    final index = current.indexWhere((c) => c.id == calendar.id);
    if (index >= 0) {
      current[index] = calendar;
      await _saveSelectedCalendars(current);
    }
  }

  /// Set the primary export calendar
  Future<void> setPrimaryExportCalendar(String calendarId) async {
    await _prefs?.setString(_keyPrimaryExportCalendarId, calendarId);
  }

  /// Save selected calendars list
  Future<void> _saveSelectedCalendars(List<SelectedCalendar> calendars) async {
    final json = jsonEncode(calendars.map((c) => c.toJson()).toList());
    await _prefs?.setString(_keySelectedCalendars, json);
  }

  /// Set sync completed tasks preference
  Future<void> setSyncCompletedTasks(bool value) async {
    await _prefs?.setBool(_keySyncCompletedTasks, value);
  }

  /// Set two-way sync preference
  Future<void> setTwoWaySyncEnabled(bool value) async {
    await _prefs?.setBool(_keyTwoWaySyncEnabled, value);
  }

  /// Set auto-sync on startup preference
  Future<void> setAutoSyncOnStartup(bool value) async {
    await _prefs?.setBool(_keyAutoSyncOnStartup, value);
  }

  /// Update last sync time
  Future<void> _updateLastSyncTime() async {
    await _prefs?.setInt(
      _keyLastSyncTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Clear all selected calendars
  Future<void> clearSelectedCalendars() async {
    await _prefs?.remove(_keySelectedCalendars);
    await _prefs?.remove(_keyPrimaryExportCalendarId);
  }

  /// Request calendar permissions
  Future<bool> requestPermissions() async {
    try {
      if (kDebugMode) {
        debugPrint(
          'CalendarSyncService: Checking if permissions already granted...',
        );
      }
      final status = await _calendarPlugin.hasPermissions();
      if (kDebugMode) {
        debugPrint('CalendarSyncService: hasPermissions result: $status');
      }

      if (status == CalendarPermissionStatus.granted) {
        if (kDebugMode) {
          debugPrint('CalendarSyncService: Permissions already granted');
        }
        return true;
      }

      if (kDebugMode) {
        debugPrint('CalendarSyncService: Requesting permissions...');
      }
      final result = await _calendarPlugin.requestPermissions();
      if (kDebugMode) {
        debugPrint('CalendarSyncService: requestPermissions result: $result');
      }
      return result == CalendarPermissionStatus.granted;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('CalendarSyncService: Error requesting permissions: $e');
        debugPrint('CalendarSyncService: Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    try {
      final status = await _calendarPlugin.hasPermissions();
      if (kDebugMode) {
        debugPrint('CalendarSyncService: hasPermissions check: $status');
      }
      return status == CalendarPermissionStatus.granted;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('CalendarSyncService: Error checking permissions: $e');
        debugPrint('CalendarSyncService: Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Get diagnostic info for troubleshooting
  Future<String> getDiagnosticInfo() async {
    final buffer = StringBuffer();

    try {
      final status = await _calendarPlugin.hasPermissions();
      buffer.writeln('Permission status: $status');

      if (status == CalendarPermissionStatus.granted) {
        final calendars = await _calendarPlugin.listCalendars();
        buffer.writeln('Calendars found: ${calendars.length}');

        for (final cal in calendars) {
          buffer.writeln(
            '  - ${cal.name}: id=${cal.id}, readOnly=${cal.readOnly}, account=${cal.accountName}, color=${cal.colorHex}',
          );
        }
      } else {
        buffer.writeln('Permissions not granted');
      }
    } catch (e, stack) {
      buffer.writeln('Exception: $e');
      buffer.writeln('Stack: $stack');
    }

    return buffer.toString();
  }

  /// Get available calendars (includes DAVx5 synced calendars)
  Future<List<Calendar>> getCalendars({bool includeReadOnly = false}) async {
    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        if (kDebugMode) {
          debugPrint('CalendarSyncService: No calendar permissions');
        }
        return [];
      }

      final calendars = await _calendarPlugin.listCalendars();
      if (kDebugMode) {
        debugPrint(
          'CalendarSyncService: listCalendars returned ${calendars.length} calendars',
        );

        // Log all calendars for debugging
        for (final cal in calendars) {
          debugPrint(
            'CalendarSyncService: Found calendar: ${cal.name}, id: ${cal.id}, readOnly: ${cal.readOnly}, accountName: ${cal.accountName}',
          );
        }
      }

      if (includeReadOnly) {
        return calendars;
      }
      // Filter to only writable calendars
      final writable = calendars.where((c) => !c.readOnly).toList();
      if (kDebugMode) {
        debugPrint(
          'CalendarSyncService: Writable calendars count: ${writable.length}',
        );
      }
      return writable;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('CalendarSyncService: Error retrieving calendars: $e');
        debugPrint('CalendarSyncService: Stack trace: $stackTrace');
      }
      return [];
    }
  }

  /// Store the mapping between task ID and calendar event ID
  Future<void> _storeEventMapping(
    String taskId,
    String eventId,
    String calendarId,
  ) async {
    await _prefs?.setString(
      '$_keyEventMappingPrefix${taskId}_$calendarId',
      eventId,
    );
  }

  /// Get the calendar event ID for a task in a specific calendar
  String? _getEventId(String taskId, String calendarId) {
    return _prefs?.getString('$_keyEventMappingPrefix${taskId}_$calendarId');
  }

  /// Remove the event mapping for a task
  Future<void> _removeEventMapping(String taskId, String calendarId) async {
    await _prefs?.remove('$_keyEventMappingPrefix${taskId}_$calendarId');
  }

  /// Check if an event has already been imported
  bool _isEventImported(String eventId) {
    return _prefs?.getString('$_keyImportedEventPrefix$eventId') != null;
  }

  /// Mark an event as imported
  Future<void> _markEventImported(String eventId, String taskId) async {
    await _prefs?.setString('$_keyImportedEventPrefix$eventId', taskId);
  }

  /// Get the task ID for an imported event
  String? _getTaskIdForEvent(String eventId) {
    return _prefs?.getString('$_keyImportedEventPrefix$eventId');
  }

  /// Create or update a calendar event for a task (exports to primary calendar only)
  Future<bool> syncTaskToCalendar(Todo task) async {
    if (!isEnabled) return false;
    final exportCal = primaryExportCalendar;
    if (exportCal == null) return false;
    if (task.dueDate == null) return false;

    // Skip tasks that were imported from a calendar
    if (task.sourceCalendarColor != null) {
      if (kDebugMode) {
        debugPrint(
          'CalendarSyncService: Skipping imported task ${task.id} (already from calendar)',
        );
      }
      return false;
    }

    if (task.isCompleted && !syncCompletedTasks) {
      await deleteTaskFromCalendar(task.id);
      return true;
    }

    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return false;

      final existingEventId = _getEventId(task.id, exportCal.id);
      final isAllDay = _isAllDayEvent(task);

      // Determine start and end times
      DateTime startTime;
      DateTime endTime;

      if (isAllDay) {
        final date = task.dueDate!;
        startTime = DateTime(date.year, date.month, date.day);
        endTime = DateTime(date.year, date.month, date.day);
      } else {
        startTime = task.startDate ?? task.dueDate!;
        endTime = task.dueDate!;
      }

      if (existingEventId != null) {
        try {
          await _calendarPlugin.updateEvent(
            eventId: existingEventId,
            title: _formatEventTitle(task),
            description: _formatEventDescription(task),
            startDate: startTime,
            endDate: endTime,
            isAllDay: isAllDay,
          );
          if (kDebugMode) {
            debugPrint(
              'CalendarSyncService: Updated event $existingEventId for task ${task.id}',
            );
          }
          return true;
        } catch (e) {
          // Event might have been deleted, try creating new one
          if (kDebugMode) {
            debugPrint(
              'CalendarSyncService: Update failed, will create new: $e',
            );
          }
          await _removeEventMapping(task.id, exportCal.id);
        }
      }

      final eventId = await _calendarPlugin.createEvent(
        calendarId: exportCal.id,
        title: _formatEventTitle(task),
        description: _formatEventDescription(task),
        startDate: startTime,
        endDate: endTime,
        isAllDay: isAllDay,
      );

      await _storeEventMapping(task.id, eventId, exportCal.id);
      if (kDebugMode) {
        debugPrint(
          'CalendarSyncService: Created event $eventId for task ${task.id}',
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CalendarSyncService: Error syncing task: $e');
      }
      return false;
    }
  }

  /// Delete a calendar event for a task from all calendars
  Future<bool> deleteTaskFromCalendar(String taskId) async {
    if (!isEnabled) return false;

    bool anyDeleted = false;
    for (final cal in exportCalendars) {
      try {
        final eventId = _getEventId(taskId, cal.id);
        if (eventId == null) continue;

        await _calendarPlugin.deleteEvent(eventId: eventId);
        await _removeEventMapping(taskId, cal.id);
        debugPrint(
          'CalendarSyncService: Deleted event $eventId for task $taskId from ${cal.name}',
        );
        anyDeleted = true;
      } catch (e) {
        debugPrint(
          'CalendarSyncService: Error deleting event from ${cal.name}: $e',
        );
      }
    }
    return anyDeleted;
  }

  /// Sync all tasks to calendar
  Future<int> syncAllTasksToCalendar(List<Todo> tasks) async {
    if (!isEnabled || primaryExportCalendar == null) return 0;

    int synced = 0;
    for (final task in tasks) {
      if (task.dueDate != null) {
        if (task.isCompleted && !syncCompletedTasks) continue;
        if (await syncTaskToCalendar(task)) {
          synced++;
        }
      }
    }

    await _updateLastSyncTime();
    debugPrint('CalendarSyncService: Synced $synced tasks to calendar');
    return synced;
  }

  /// Get events from import calendars for a date range
  Future<List<CalendarEventInfo>> getEventsForImport({
    required DateTime startDate,
    required DateTime endDate,
    bool includeAlreadyImported = false,
  }) async {
    if (!isEnabled || !twoWaySyncEnabled) return [];

    final events = <CalendarEventInfo>[];

    for (final cal in importCalendars) {
      try {
        final calendarEvents = await _calendarPlugin.listEvents(
          startDate,
          endDate,
          calendarIds: [cal.id],
        );

        for (final event in calendarEvents) {
          final isFromTrudido =
              event.description?.contains('Synced from Trudido') == true;
          final isAlreadyImported = _isEventImported(event.instanceId);

          if (!includeAlreadyImported && isAlreadyImported) continue;
          if (isFromTrudido) continue; // Don't re-import our own events

          events.add(
            CalendarEventInfo(
              eventId: event.instanceId,
              title: event.title,
              description: event.description,
              startDate: event.startDate,
              endDate: event.endDate,
              isAllDay: event.isAllDay,
              isFromTrudido: isFromTrudido,
              isAlreadyImported: isAlreadyImported,
              linkedTaskId: _getTaskIdForEvent(event.instanceId),
            ),
          );
        }
      } catch (e) {
        debugPrint(
          'CalendarSyncService: Error getting events from ${cal.name}: $e',
        );
      }
    }

    return events;
  }

  /// Import a calendar event as a task
  Future<Todo?> importEventAsTask(String eventId) async {
    if (!isEnabled || !twoWaySyncEnabled) return null;

    try {
      final event = await _calendarPlugin.getEvent(eventId);
      if (event == null) return null;

      // Find which calendar this event belongs to
      SelectedCalendar? sourceCalendar;
      for (final cal in importCalendars) {
        try {
          final calEvents = await _calendarPlugin.listEvents(
            event.startDate.subtract(const Duration(days: 1)),
            event.endDate.add(const Duration(days: 1)),
            calendarIds: [cal.id],
          );
          if (calEvents.any((e) => e.instanceId == eventId)) {
            sourceCalendar = cal;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      final task = Todo(
        text: event.title,
        notes: event.description,
        dueDate: event.isAllDay
            ? DateTime(
                event.startDate.year,
                event.startDate.month,
                event.startDate.day,
              )
            : event.endDate,
        startDate: event.isAllDay ? null : event.startDate,
        sourceCalendarColor: sourceCalendar?.color,
      );

      // Mark as imported
      await _markEventImported(eventId, task.id);

      debugPrint(
        'CalendarSyncService: Imported event $eventId as task ${task.id}',
      );
      return task;
    } catch (e) {
      debugPrint('CalendarSyncService: Error importing event: $e');
      return null;
    }
  }

  /// Get sync status info
  Future<CalendarSyncStatus> getSyncStatus() async {
    final hasPerms = await hasPermissions();
    final allCalendars = hasPerms
        ? await getCalendars(includeReadOnly: true)
        : <Calendar>[];
    final writableCalendars = allCalendars.where((c) => !c.readOnly).toList();

    return CalendarSyncStatus(
      isEnabled: isEnabled,
      hasPermissions: hasPerms,
      selectedCalendars: selectedCalendars,
      primaryExportCalendarId: primaryExportCalendarId,
      availableCalendars: writableCalendars,
      allCalendars: allCalendars,
      syncCompletedTasks: syncCompletedTasks,
      twoWaySyncEnabled: twoWaySyncEnabled,
      autoSyncOnStartup: autoSyncOnStartup,
      lastSyncTime: lastSyncTime,
    );
  }

  /// Format event title from task
  String _formatEventTitle(Todo task) {
    String title = task.text;
    final priorityLevel = _getPriorityLevel(task.priority);
    if (priorityLevel > 0) {
      title = '${'!' * priorityLevel} $title';
    }
    return title;
  }

  /// Convert priority string to level
  int _getPriorityLevel(String priority) {
    switch (priority) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  /// Format event description from task
  String _formatEventDescription(Todo task) {
    final parts = <String>[];

    if (task.notes != null && task.notes!.isNotEmpty) {
      parts.add(task.notes!);
      parts.add('');
    }

    if (task.tags.isNotEmpty) {
      parts.add('Tags: ${task.tags.join(', ')}');
    }

    parts.add('Priority: ${task.priority}');
    parts.add('Status: ${task.isCompleted ? 'Completed' : 'Pending'}');
    parts.add('\n---\nSynced from Trudido');

    return parts.join('\n');
  }

  /// Check if task should be an all-day event
  bool _isAllDayEvent(Todo task) {
    if (task.dueDate == null) return true;

    final due = task.dueDate!;
    return due.hour == 0 && due.minute == 0 && due.second == 0;
  }

  /// Delete all Trudido events from a calendar
  Future<int> deleteTrudidoEventsFromCalendar({
    required String calendarId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return 0;

      final events = await _calendarPlugin.listEvents(
        startDate,
        endDate,
        calendarIds: [calendarId],
      );

      int deleted = 0;
      for (final event in events) {
        if (event.description?.contains('Synced from Trudido') == true) {
          try {
            await _calendarPlugin.deleteEvent(eventId: event.instanceId);
            deleted++;
          } catch (e) {
            debugPrint('CalendarSyncService: Error deleting event: $e');
          }
        }
      }

      // Clear event mappings
      final keys =
          _prefs
              ?.getKeys()
              .where((k) => k.startsWith(_keyEventMappingPrefix))
              .toList() ??
          [];
      for (final key in keys) {
        await _prefs?.remove(key);
      }

      debugPrint('CalendarSyncService: Deleted $deleted Trudido events');
      return deleted;
    } catch (e) {
      debugPrint('CalendarSyncService: Error deleting events: $e');
      return 0;
    }
  }

  /// Import events from a specific calendar as tasks
  Future<List<Todo>> importEventsFromCalendar({
    required String calendarId,
    required DateTime startDate,
    required DateTime endDate,
    bool skipAlreadyImported = true,
  }) async {
    final todos = <Todo>[];

    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return todos;

      final events = await _calendarPlugin.listEvents(
        startDate,
        endDate,
        calendarIds: [calendarId],
      );

      // Find the calendar's color
      final calendars = await _calendarPlugin.listCalendars();
      final calendar = calendars.where((c) => c.id == calendarId).firstOrNull;
      final calendarColor = calendar != null
          ? parseColorHex(calendar.colorHex)
          : 0xFF2196F3;

      for (final event in events) {
        // Skip our own events
        if (event.description?.contains('Synced from Trudido') == true) {
          continue;
        }

        // Skip already imported
        if (skipAlreadyImported && _isEventImported(event.instanceId)) {
          continue;
        }

        final todo = Todo(
          text: event.title,
          notes: event.description,
          dueDate: event.isAllDay
              ? DateTime(
                  event.startDate.year,
                  event.startDate.month,
                  event.startDate.day,
                )
              : event.endDate,
          startDate: event.isAllDay ? null : event.startDate,
          sourceCalendarColor: calendarColor,
        );

        await _markEventImported(event.instanceId, todo.id);
        todos.add(todo);
      }
    } catch (e) {
      debugPrint('CalendarSyncService: Error importing events: $e');
    }

    return todos;
  }

  /// Perform two-way sync
  Future<TwoWaySyncResult> performTwoWaySync({
    required List<Todo> existingTasks,
    required DateTime syncStartDate,
    required DateTime syncEndDate,
  }) async {
    final exported = <String>[];
    final imported = <Todo>[];

    // Export tasks to calendar
    for (final task in existingTasks) {
      if (task.dueDate != null && !task.isCompleted) {
        if (await syncTaskToCalendar(task)) {
          exported.add(task.id);
        }
      }
    }

    // Import events from calendars
    for (final cal in importCalendars) {
      final todos = await importEventsFromCalendar(
        calendarId: cal.id,
        startDate: syncStartDate,
        endDate: syncEndDate,
        skipAlreadyImported: true,
      );
      imported.addAll(todos);
    }

    await _updateLastSyncTime();

    return TwoWaySyncResult(exported: exported, imported: imported);
  }

  /// Delete duplicate Trudido events from a calendar
  Future<int> deleteDuplicateTrudidoEvents({
    required String calendarId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return 0;

      final events = await _calendarPlugin.listEvents(
        startDate,
        endDate,
        calendarIds: [calendarId],
      );

      // Group events by title
      final eventsByTitle = <String, List<Event>>{};
      for (final event in events) {
        if (event.description?.contains('Synced from Trudido') == true) {
          eventsByTitle.putIfAbsent(event.title, () => []).add(event);
        }
      }

      int deleted = 0;
      for (final entry in eventsByTitle.entries) {
        if (entry.value.length > 1) {
          // Keep the first, delete duplicates
          for (var i = 1; i < entry.value.length; i++) {
            try {
              await _calendarPlugin.deleteEvent(
                eventId: entry.value[i].instanceId,
              );
              deleted++;
            } catch (e) {
              debugPrint('CalendarSyncService: Error deleting duplicate: $e');
            }
          }
        }
      }

      debugPrint('CalendarSyncService: Deleted $deleted duplicate events');
      return deleted;
    } catch (e) {
      debugPrint('CalendarSyncService: Error cleaning duplicates: $e');
      return 0;
    }
  }

  /// Delete all Trudido events from a calendar
  Future<int> deleteAllTrudidoEvents({
    required String calendarId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Reuse the existing method
    return deleteTrudidoEventsFromCalendar(
      calendarId: calendarId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Helper to parse color hex string to int
  static int parseColorHex(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return 0xFF2196F3; // Default blue
    }
    try {
      String hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // Add alpha if missing
      }
      return int.parse(hex, radix: 16);
    } catch (e) {
      return 0xFF2196F3;
    }
  }
}

/// Result of a two-way sync operation
class TwoWaySyncResult {
  final List<String> exported;
  final List<Todo> imported;

  const TwoWaySyncResult({required this.exported, required this.imported});
}

/// Status object for calendar sync
class CalendarSyncStatus {
  final bool isEnabled;
  final bool hasPermissions;
  final List<SelectedCalendar> selectedCalendars;
  final String? primaryExportCalendarId;
  final List<Calendar> availableCalendars;
  final List<Calendar> allCalendars;
  final bool syncCompletedTasks;
  final bool twoWaySyncEnabled;
  final bool autoSyncOnStartup;
  final DateTime? lastSyncTime;

  const CalendarSyncStatus({
    required this.isEnabled,
    required this.hasPermissions,
    required this.selectedCalendars,
    required this.primaryExportCalendarId,
    required this.availableCalendars,
    required this.allCalendars,
    required this.syncCompletedTasks,
    required this.twoWaySyncEnabled,
    required this.autoSyncOnStartup,
    required this.lastSyncTime,
  });

  bool get isConfigured =>
      isEnabled && hasPermissions && selectedCalendars.isNotEmpty;

  SelectedCalendar? get primaryExportCalendar {
    if (primaryExportCalendarId == null) return null;
    return selectedCalendars
        .where((c) => c.id == primaryExportCalendarId)
        .firstOrNull;
  }

  List<SelectedCalendar> get exportCalendars =>
      selectedCalendars.where((c) => c.isForExport).toList();

  List<SelectedCalendar> get importCalendars =>
      selectedCalendars.where((c) => c.isForImport).toList();
}

/// Info about a calendar event for display
class CalendarEventInfo {
  final String eventId;
  final String title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isAllDay;
  final bool isFromTrudido;
  final bool isAlreadyImported;
  final String? linkedTaskId;

  const CalendarEventInfo({
    required this.eventId,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    required this.isAllDay,
    required this.isFromTrudido,
    required this.isAlreadyImported,
    this.linkedTaskId,
  });
}
