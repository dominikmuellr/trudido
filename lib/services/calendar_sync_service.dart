import 'dart:convert';
import 'package:device_calendar/device_calendar.dart';
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

/// Service for syncing tasks with the device calendar.
/// Works seamlessly with DAVx5 for CalDAV sync - users configure their
/// CalDAV account in DAVx5, and this service reads/writes to Android calendar.
///
/// Supports bi-directional sync:
/// - Trudido → Calendar: Tasks with due dates become calendar events
/// - Calendar → Trudido: Calendar events can be imported as tasks
///
/// Supports multiple calendars for work, personal, shared calendars, etc.
class CalendarSyncService {
  static final CalendarSyncService _instance = CalendarSyncService._internal();
  factory CalendarSyncService() => _instance;
  CalendarSyncService._internal();

  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
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

  /// Initialize the service
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _migrateFromSingleCalendar();
    _isInitialized = true;
  }

  /// Migrate from single calendar to multiple calendars
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
      debugPrint('CalendarSyncService: Error parsing selected calendars: $e');
      return [];
    }
  }

  /// Get primary export calendar ID (where new tasks are exported)
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

  /// Get the last sync time
  DateTime? get lastSyncTime {
    final ms = _prefs?.getInt(_keyLastSyncTime);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Enable or disable calendar sync
  Future<void> setEnabled(bool enabled) async {
    await _prefs?.setBool(_keyCalendarSyncEnabled, enabled);
  }

  /// Add a selected calendar
  Future<void> addSelectedCalendar(SelectedCalendar calendar) async {
    final calendars = List<SelectedCalendar>.from(selectedCalendars);
    // Remove existing entry with same ID if present
    calendars.removeWhere((c) => c.id == calendar.id);
    calendars.add(calendar);
    await _saveSelectedCalendars(calendars);

    // If this is the first calendar and it's for export, make it primary
    if (calendar.isForExport && primaryExportCalendarId == null) {
      await setPrimaryExportCalendar(calendar.id);
    }
  }

  /// Remove a selected calendar
  Future<void> removeSelectedCalendar(String calendarId) async {
    final calendars = List<SelectedCalendar>.from(selectedCalendars);
    calendars.removeWhere((c) => c.id == calendarId);
    await _saveSelectedCalendars(calendars);

    // If we removed the primary export calendar, select a new one
    if (primaryExportCalendarId == calendarId) {
      final exportCals = calendars.where((c) => c.isForExport).toList();
      if (exportCals.isNotEmpty) {
        await setPrimaryExportCalendar(exportCals.first.id);
      } else {
        await _prefs?.remove(_keyPrimaryExportCalendarId);
      }
    }
  }

  /// Update a selected calendar's settings
  Future<void> updateSelectedCalendar(SelectedCalendar calendar) async {
    final calendars = List<SelectedCalendar>.from(selectedCalendars);
    final index = calendars.indexWhere((c) => c.id == calendar.id);
    if (index >= 0) {
      calendars[index] = calendar;
      await _saveSelectedCalendars(calendars);
    }
  }

  /// Save selected calendars to preferences
  Future<void> _saveSelectedCalendars(List<SelectedCalendar> calendars) async {
    final json = jsonEncode(calendars.map((c) => c.toJson()).toList());
    await _prefs?.setString(_keySelectedCalendars, json);
  }

  /// Set the primary export calendar
  Future<void> setPrimaryExportCalendar(String calendarId) async {
    await _prefs?.setString(_keyPrimaryExportCalendarId, calendarId);
  }

  /// Set whether to sync completed tasks
  Future<void> setSyncCompletedTasks(bool sync) async {
    await _prefs?.setBool(_keySyncCompletedTasks, sync);
  }

  /// Enable or disable two-way sync
  Future<void> setTwoWaySyncEnabled(bool enabled) async {
    await _prefs?.setBool(_keyTwoWaySyncEnabled, enabled);
  }

  /// Enable or disable auto-sync on startup
  Future<void> setAutoSyncOnStartup(bool enabled) async {
    await _prefs?.setBool(_keyAutoSyncOnStartup, enabled);
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
      final permissionsGranted = await _calendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && permissionsGranted.data == true) {
        return true;
      }

      final result = await _calendarPlugin.requestPermissions();
      return result.isSuccess && result.data == true;
    } catch (e) {
      debugPrint('CalendarSyncService: Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    try {
      final result = await _calendarPlugin.hasPermissions();
      return result.isSuccess && result.data == true;
    } catch (e) {
      debugPrint('CalendarSyncService: Error checking permissions: $e');
      return false;
    }
  }

  /// Get available calendars (includes DAVx5 synced calendars)
  Future<List<Calendar>> getCalendars({bool includeReadOnly = false}) async {
    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        debugPrint('CalendarSyncService: No calendar permissions');
        return [];
      }

      final result = await _calendarPlugin.retrieveCalendars();
      if (result.isSuccess && result.data != null) {
        if (includeReadOnly) {
          return result.data!;
        }
        // Filter to only writable calendars
        return result.data!.where((c) => !c.isReadOnly!).toList();
      }
      return [];
    } catch (e) {
      debugPrint('CalendarSyncService: Error retrieving calendars: $e');
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
  /// Only creates a new event if one doesn't already exist for this task
  /// Skips tasks that were imported from a calendar to avoid duplicates
  Future<bool> syncTaskToCalendar(Todo task) async {
    if (!isEnabled) return false;
    final exportCal = primaryExportCalendar;
    if (exportCal == null) return false;
    if (task.dueDate == null) return false;

    // Skip tasks that were imported from a calendar - they already exist there!
    if (task.sourceCalendarColor != null) {
      debugPrint(
        'CalendarSyncService: Skipping imported task ${task.id} (already from calendar)',
      );
      return false;
    }

    if (task.isCompleted && !syncCompletedTasks) {
      // If task is completed and we don't sync completed tasks, delete it
      await deleteTaskFromCalendar(task.id);
      return true;
    }

    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return false;

      final existingEventId = _getEventId(task.id, exportCal.id);

      // If we already have an event ID mapped, verify it still exists
      // If it exists, update it; if not, we'll create a new one
      String? eventIdToUse = existingEventId;

      if (existingEventId != null) {
        // Check if the event still exists in the calendar
        final eventExists = await _checkEventExists(
          exportCal.id,
          existingEventId,
          task.dueDate!,
        );
        if (!eventExists) {
          // Event was deleted from calendar, remove our mapping
          await _removeEventMapping(task.id, exportCal.id);
          eventIdToUse = null;
        }
      }

      // Create the event
      final isAllDay = _isAllDayEvent(task);

      // For all-day events, use the date at noon UTC to avoid timezone issues
      // This ensures the date is correct regardless of timezone
      TZDateTime startTime;
      TZDateTime endTime;

      if (isAllDay) {
        // Use noon UTC for all-day events to avoid date shifting
        final date = task.dueDate!;
        startTime = TZDateTime.utc(date.year, date.month, date.day, 12, 0, 0);
        endTime = TZDateTime.utc(date.year, date.month, date.day, 12, 0, 0);
      } else {
        // For timed events, use local timezone
        startTime = TZDateTime.from(task.startDate ?? task.dueDate!, local);
        endTime = TZDateTime.from(task.dueDate!, local);
      }

      final event = Event(
        exportCal.id,
        eventId: eventIdToUse,
        title: _formatEventTitle(task),
        description: _formatEventDescription(task),
        start: startTime,
        end: endTime,
        allDay: isAllDay,
      );

      final result = await _calendarPlugin.createOrUpdateEvent(event);

      if (result?.isSuccess == true && result?.data != null) {
        await _storeEventMapping(task.id, result!.data!, exportCal.id);
        debugPrint(
          'CalendarSyncService: Synced task ${task.id} to event ${result.data} (${eventIdToUse != null ? 'updated' : 'created'})',
        );
        return true;
      }

      debugPrint('CalendarSyncService: Failed to sync task ${task.id}');
      return false;
    } catch (e) {
      debugPrint('CalendarSyncService: Error syncing task: $e');
      return false;
    }
  }

  /// Check if an event exists in a calendar
  Future<bool> _checkEventExists(
    String calendarId,
    String eventId,
    DateTime aroundDate,
  ) async {
    try {
      // Search in a range around the expected date
      final startDate = aroundDate.subtract(const Duration(days: 30));
      final endDate = aroundDate.add(const Duration(days: 30));

      final result = await _calendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: startDate, endDate: endDate),
      );

      if (result.isSuccess && result.data != null) {
        return result.data!.any((e) => e.eventId == eventId);
      }
      return false;
    } catch (e) {
      debugPrint('CalendarSyncService: Error checking event exists: $e');
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

        final result = await _calendarPlugin.deleteEvent(cal.id, eventId);

        if (result.isSuccess) {
          await _removeEventMapping(taskId, cal.id);
          debugPrint(
            'CalendarSyncService: Deleted event $eventId for task $taskId from ${cal.name}',
          );
          anyDeleted = true;
        }
      } catch (e) {
        debugPrint(
          'CalendarSyncService: Error deleting event from ${cal.name}: $e',
        );
      }
    }
    return anyDeleted;
  }

  /// Sync all tasks to calendar (initial sync or full resync)
  /// Only exports tasks that haven't been exported yet, or updates existing ones
  Future<int> syncAllTasks(List<Todo> tasks) async {
    if (!isEnabled || exportCalendars.isEmpty) return 0;

    int synced = 0;
    for (final task in tasks) {
      if (task.dueDate != null) {
        final success = await syncTaskToCalendar(task);
        if (success) synced++;
      }
    }
    await _updateLastSyncTime();
    debugPrint('CalendarSyncService: Synced $synced tasks to calendar');
    return synced;
  }

  /// Check if a task has already been exported to the calendar
  bool isTaskExported(String taskId) {
    final exportCal = primaryExportCalendar;
    if (exportCal == null) return false;
    return _getEventId(taskId, exportCal.id) != null;
  }

  /// Get the count of tasks that would be exported (not already in calendar)
  /// Excludes tasks imported from calendars
  int getNewTasksToExportCount(List<Todo> tasks) {
    return tasks
        .where(
          (t) =>
              t.dueDate != null &&
              t.sourceCalendarColor == null && // Not imported from calendar
              !isTaskExported(t.id) &&
              (syncCompletedTasks || !t.isCompleted),
        )
        .length;
  }

  /// Import events from all import-enabled calendars as tasks
  Future<List<Todo>> importEventsFromCalendar({
    String? calendarId, // If null, imports from all import calendars
    required DateTime startDate,
    required DateTime endDate,
    bool skipAlreadyImported = true,
  }) async {
    if (!isEnabled) return [];

    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return [];

      final calendarsToImport = calendarId != null
          ? [selectedCalendars.firstWhere((c) => c.id == calendarId)]
          : importCalendars;

      final todos = <Todo>[];

      for (final cal in calendarsToImport) {
        final result = await _calendarPlugin.retrieveEvents(
          cal.id,
          RetrieveEventsParams(startDate: startDate, endDate: endDate),
        );

        if (!result.isSuccess || result.data == null) {
          debugPrint(
            'CalendarSyncService: Failed to retrieve events from ${cal.name}',
          );
          continue;
        }

        for (final event in result.data!) {
          // Skip if already imported
          if (skipAlreadyImported &&
              event.eventId != null &&
              _isEventImported(event.eventId!)) {
            continue;
          }

          // Skip events that were created by Trudido (to avoid duplicates)
          if (event.description?.contains('Synced from Trudido') == true) {
            continue;
          }

          final todo = _eventToTodo(event, cal.name, cal.color);
          if (todo != null) {
            todos.add(todo);
            if (event.eventId != null) {
              await _markEventImported(event.eventId!, todo.id);
            }
          }
        }
      }

      await _updateLastSyncTime();
      debugPrint(
        'CalendarSyncService: Imported ${todos.length} events as tasks',
      );
      return todos;
    } catch (e) {
      debugPrint('CalendarSyncService: Error importing events: $e');
      return [];
    }
  }

  /// Get events from a calendar without importing
  Future<List<CalendarEventInfo>> getCalendarEvents({
    required String calendarId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return [];

      final result = await _calendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: startDate, endDate: endDate),
      );

      if (!result.isSuccess || result.data == null) {
        return [];
      }

      return result.data!.map((event) {
        final isFromTrudido =
            event.description?.contains('Synced from Trudido') == true;
        final isImported =
            event.eventId != null && _isEventImported(event.eventId!);

        return CalendarEventInfo(
          eventId: event.eventId ?? '',
          title: event.title ?? 'Untitled',
          description: event.description,
          startDate: event.start?.toLocal(),
          endDate: event.end?.toLocal(),
          isAllDay: event.allDay ?? false,
          isFromTrudido: isFromTrudido,
          isAlreadyImported: isImported,
          linkedTaskId: isImported ? _getTaskIdForEvent(event.eventId!) : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('CalendarSyncService: Error getting events: $e');
      return [];
    }
  }

  /// Convert a calendar event to a Todo
  Todo? _eventToTodo(Event event, [String? calendarName, int? calendarColor]) {
    if (event.title == null || event.title!.isEmpty) return null;

    final startTime = event.start?.toLocal();
    final endTime = event.end?.toLocal();

    if (endTime == null) return null;

    // Clean up title (remove any status prefixes we might have added)
    String title = event.title!;
    if (title.startsWith('✓ ')) {
      title = title.substring(2);
    } else if (title.startsWith('❗ ')) {
      title = title.substring(2);
    } else if (title.startsWith('• ')) {
      title = title.substring(2);
    }

    // Parse notes from description (exclude our metadata)
    String? notes;
    if (event.description != null) {
      final descLines = event.description!.split('\n');
      final notesLines = <String>[];
      for (final line in descLines) {
        if (line.startsWith('Tags:') ||
            line.startsWith('Priority:') ||
            line.startsWith('Status:') ||
            line.contains('Synced from Trudido') ||
            line == '---') {
          continue;
        }
        notesLines.add(line);
      }
      final cleanNotes = notesLines.join('\n').trim();
      if (cleanNotes.isNotEmpty) {
        notes = cleanNotes;
      }
    }

    // Add calendar source info to notes
    if (calendarName != null) {
      final sourceInfo = 'Imported from: $calendarName';
      notes = notes != null ? '$notes\n\n$sourceInfo' : sourceInfo;
    }

    return Todo(
      text: title,
      dueDate: endTime,
      startDate: (startTime != null && startTime != endTime) ? startTime : null,
      notes: notes,
      priority: 'none',
      sourceCalendarColor: calendarColor,
    );
  }

  /// Perform full two-way sync with all configured calendars
  Future<({int exported, List<Todo> imported})> performTwoWaySync({
    required List<Todo> existingTasks,
    required DateTime syncStartDate,
    required DateTime syncEndDate,
  }) async {
    if (!isEnabled || selectedCalendars.isEmpty) {
      return (exported: 0, imported: <Todo>[]);
    }

    // First, export tasks to calendar
    final exported = await syncAllTasks(existingTasks);

    // Then, import events from all import calendars (if two-way sync is enabled)
    List<Todo> imported = [];
    if (twoWaySyncEnabled) {
      imported = await importEventsFromCalendar(
        startDate: syncStartDate,
        endDate: syncEndDate,
        skipAlreadyImported: true,
      );
    }

    return (exported: exported, imported: imported);
  }

  /// Format the event title
  String _formatEventTitle(Todo task) {
    String title = task.text;
    if (task.isCompleted) {
      title = '✓ $title';
    } else if (task.priority == 'high') {
      title = '❗ $title';
    } else if (task.priority == 'medium') {
      title = '• $title';
    }
    return title;
  }

  /// Format the event description
  String _formatEventDescription(Todo task) {
    final parts = <String>[];

    if (task.notes?.isNotEmpty == true) {
      parts.add(task.notes!);
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

    // If due date has no time component (midnight), treat as all-day
    final due = task.dueDate!;
    return due.hour == 0 && due.minute == 0 && due.second == 0;
  }

  /// Get sync status info
  Future<CalendarSyncStatus> getSyncStatus() async {
    final hasPerms = await hasPermissions();
    final calendars = hasPerms ? await getCalendars() : <Calendar>[];

    return CalendarSyncStatus(
      isEnabled: isEnabled,
      hasPermissions: hasPerms,
      selectedCalendars: selectedCalendars,
      primaryExportCalendarId: primaryExportCalendarId,
      availableCalendars: calendars,
      syncCompletedTasks: syncCompletedTasks,
      twoWaySyncEnabled: twoWaySyncEnabled,
      autoSyncOnStartup: autoSyncOnStartup,
      lastSyncTime: lastSyncTime,
    );
  }

  /// Delete all duplicate Trudido events from a calendar
  /// Keeps only one event per unique title+date combination
  Future<int> deleteDuplicateTrudidoEvents({
    required String calendarId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return 0;

      final result = await _calendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: startDate, endDate: endDate),
      );

      if (!result.isSuccess || result.data == null) {
        return 0;
      }

      // Find Trudido events and group by title+date
      final trudiloEvents = result.data!
          .where((e) => e.description?.contains('Synced from Trudido') == true)
          .toList();

      // Group by title and start date
      final groups = <String, List<Event>>{};
      for (final event in trudiloEvents) {
        final key = '${event.title}_${event.start?.toIso8601String()}';
        groups.putIfAbsent(key, () => []).add(event);
      }

      // Delete duplicates (keep first one of each group)
      int deleted = 0;
      for (final group in groups.values) {
        if (group.length > 1) {
          // Sort by event ID to keep consistent which one we keep
          group.sort((a, b) => (a.eventId ?? '').compareTo(b.eventId ?? ''));
          // Delete all except the first one
          for (int i = 1; i < group.length; i++) {
            final eventId = group[i].eventId;
            if (eventId != null) {
              final deleteResult = await _calendarPlugin.deleteEvent(
                calendarId,
                eventId,
              );
              if (deleteResult.isSuccess) {
                deleted++;
                debugPrint(
                  'CalendarSyncService: Deleted duplicate event $eventId',
                );
              }
            }
          }
        }
      }

      debugPrint('CalendarSyncService: Deleted $deleted duplicate events');
      return deleted;
    } catch (e) {
      debugPrint('CalendarSyncService: Error deleting duplicates: $e');
      return 0;
    }
  }

  /// Delete ALL Trudido events from a calendar (useful for resetting)
  Future<int> deleteAllTrudidoEvents({
    required String calendarId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return 0;

      final result = await _calendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: startDate, endDate: endDate),
      );

      if (!result.isSuccess || result.data == null) {
        return 0;
      }

      int deleted = 0;
      for (final event in result.data!) {
        if (event.description?.contains('Synced from Trudido') == true) {
          final eventId = event.eventId;
          if (eventId != null) {
            final deleteResult = await _calendarPlugin.deleteEvent(
              calendarId,
              eventId,
            );
            if (deleteResult.isSuccess) {
              deleted++;
            }
          }
        }
      }

      // Clear all event mappings
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
}

/// Status object for calendar sync
class CalendarSyncStatus {
  final bool isEnabled;
  final bool hasPermissions;
  final List<SelectedCalendar> selectedCalendars;
  final String? primaryExportCalendarId;
  final List<Calendar> availableCalendars;
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
    required this.syncCompletedTasks,
    required this.twoWaySyncEnabled,
    required this.autoSyncOnStartup,
    required this.lastSyncTime,
  });

  bool get isConfigured =>
      isEnabled && hasPermissions && selectedCalendars.isNotEmpty;

  /// Get the primary export calendar
  SelectedCalendar? get primaryExportCalendar {
    if (primaryExportCalendarId == null) return null;
    return selectedCalendars
        .where((c) => c.id == primaryExportCalendarId)
        .firstOrNull;
  }

  /// Get calendars enabled for export
  List<SelectedCalendar> get exportCalendars =>
      selectedCalendars.where((c) => c.isForExport).toList();

  /// Get calendars enabled for import
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
