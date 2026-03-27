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

/// Manages UI filtering state for tasks and notes (search, sort, view mode).
/// These providers control what the user sees in task/note lists.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import '../models/event.dart';
import '../utils/date_search_parser.dart';
import 'app_providers.dart';
import '../services/folder_provider.dart';
import '../widgets/calendar_view.dart';
import '../utils/state_notifiers.dart';
import '../services/storage_service.dart';

// Filter state providers
final searchQueryProvider = stateProvider<String>('');
final selectedPriorityProvider = stateProvider<String>('all');
final showCompletedProvider = stateProvider<bool>(true);
final sortByProvider = stateProvider<String>(
  'default',
); // default|date_created|date_due|priority|alphabetical|manual
final dueTodayFilterProvider = stateProvider<bool>(false);

/// Secondary sort keys for multi-sort. Primary sort is sortByProvider.
/// Example: ['alphabetical'] means sort by primary first, then alphabetical.
final secondarySortKeysProvider = stateProvider<List<String>>([]);

/// Filter for task list tab: show 'all', 'tasks_only', or 'events_only'
final listItemTypeFilterProvider = stateProvider<String>('all');

/// Overview drawer configurable modules (3 slots).
/// Each slot is a module type: 'task_folders', 'note_folders', or 'none'.
class OverviewDrawerModulesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return StorageService.getOverviewDrawerModules();
  }

  void setModule(int index, String moduleType) {
    final modules = [...state];
    modules[index] = moduleType;
    state = modules;
    StorageService.setOverviewDrawerModules(modules);
  }
}

final overviewDrawerModulesProvider =
    NotifierProvider<OverviewDrawerModulesNotifier, List<String>>(
      OverviewDrawerModulesNotifier.new,
    );

/// Per-tab drawer module (single module slot for Tasks/Notes tabs).
class TabDrawerModuleNotifier extends Notifier<String> {
  final int tab;
  TabDrawerModuleNotifier(this.tab);

  @override
  String build() {
    return StorageService.getTabDrawerModule(tab);
  }

  void setModule(String moduleType) {
    state = moduleType;
    StorageService.setTabDrawerModule(tab, moduleType);
  }
}

final tasksDrawerModuleProvider =
    NotifierProvider<TabDrawerModuleNotifier, String>(
      () => TabDrawerModuleNotifier(1),
    );

final notesDrawerModuleProvider =
    NotifierProvider<TabDrawerModuleNotifier, String>(
      () => TabDrawerModuleNotifier(2),
    );

/// Overview section order (drag-and-drop configurable).
class OverviewSectionOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    var stored = StorageService.getOverviewSectionOrder();
    var changed = false;
    // Migrate: remove legacy 'pinned_note' section
    if (stored.contains('pinned_note')) {
      stored = stored.where((s) => s != 'pinned_note').toList();
      changed = true;
    }
    // Migrate: add 'recent_settings' if not yet present
    if (!stored.contains('recent_settings')) {
      stored = [...stored, 'recent_settings'];
      changed = true;
    }
    // Migrate: add 'greeting' to front if not yet present
    if (!stored.contains('greeting')) {
      stored = ['greeting', ...stored];
      changed = true;
    }
    // Migrate: add 'folder_shortcuts' after greeting if not yet present
    if (!stored.contains('folder_shortcuts')) {
      final idx = stored.indexOf('greeting');
      final insertAt = idx >= 0 ? idx + 1 : 1;
      stored = [
        ...stored.sublist(0, insertAt),
        'folder_shortcuts',
        ...stored.sublist(insertAt),
      ];
      changed = true;
    }
    // Migrate: add 'clock' before 'greeting' if not yet present
    if (!stored.contains('clock')) {
      final idx = stored.indexOf('greeting');
      final insertAt = idx >= 0 ? idx : 0;
      stored = [
        ...stored.sublist(0, insertAt),
        'clock',
        ...stored.sublist(insertAt),
      ];
      changed = true;
    }
    if (changed) StorageService.setOverviewSectionOrder(stored);
    return stored;
  }

  void reorder(List<String> newOrder) {
    state = newOrder;
    StorageService.setOverviewSectionOrder(newOrder);
  }
}

final overviewSectionOrderProvider =
    NotifierProvider<OverviewSectionOrderNotifier, List<String>>(
      OverviewSectionOrderNotifier.new,
    );

/// Overview hidden sections (sections excluded from display).
class OverviewHiddenSectionsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return StorageService.getOverviewHiddenSections();
  }

  void toggle(String section) {
    final next = {...state};
    if (next.contains(section)) {
      next.remove(section);
    } else {
      next.add(section);
    }
    state = next;
    StorageService.setOverviewHiddenSections(next);
  }
}

final overviewHiddenSectionsProvider =
    NotifierProvider<OverviewHiddenSectionsNotifier, Set<String>>(
      OverviewHiddenSectionsNotifier.new,
    );

/// Recently visited settings screens (keys, most recent first, max 3).
class RecentSettingsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => StorageService.getRecentSettings();

  void record(String key) {
    final next = [key, ...state.where((k) => k != key)].take(3).toList();
    state = next;
    StorageService.setRecentSettings(next);
  }
}

final recentSettingsProvider =
    NotifierProvider<RecentSettingsNotifier, List<String>>(
      RecentSettingsNotifier.new,
    );

/// Pinned overview note ID.
class PinnedOverviewNoteNotifier extends Notifier<String?> {
  @override
  String? build() {
    return StorageService.getPinnedOverviewNoteId();
  }

  void pin(String noteId) {
    state = noteId;
    StorageService.setPinnedOverviewNoteId(noteId);
  }

  void unpin() {
    state = null;
    StorageService.setPinnedOverviewNoteId(null);
  }
}

final pinnedOverviewNoteProvider =
    NotifierProvider<PinnedOverviewNoteNotifier, String?>(
      PinnedOverviewNoteNotifier.new,
    );

// View state providers
enum TaskViewType { list, calendar }

final taskViewTypeProvider = stateProvider<TaskViewType>(TaskViewType.list);
final selectedCalendarDateProvider = stateProvider<DateTime?>(null);

// Calendar format notifier with persistence
class CalendarFormatNotifier extends Notifier<CustomCalendarFormat> {
  @override
  CustomCalendarFormat build() {
    _loadSavedFormat();
    return CustomCalendarFormat.month;
  }

  Future<void> _loadSavedFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt('calendar_format_index');
      if (savedIndex != null &&
          savedIndex < CustomCalendarFormat.values.length) {
        state = CustomCalendarFormat.values[savedIndex];
      }
    } catch (e) {
      // Silently fall back to default month format if SharedPreferences unavailable
    }
  }

  Future<void> setFormat(CustomCalendarFormat format) async {
    state = format;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('calendar_format_index', format.index);
    } catch (e) {
      // Silently ignore save failure - format will reset on app restart
    }
  }
}

final calendarFormatProvider =
    NotifierProvider<CalendarFormatNotifier, CustomCalendarFormat>(
      CalendarFormatNotifier.new,
    );

/// Derived filtered task list based on filters above.
final filteredTasksProvider = Provider<List<Todo>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final selectedPriority = ref.watch(selectedPriorityProvider);
  final showCompleted = ref.watch(showCompletedProvider);
  final sortBy = ref.watch(sortByProvider);
  final dueTodayFilter = ref.watch(dueTodayFilterProvider);
  // Folder filter still comes from legacy folder provider (not yet migrated)
  final selectedFolder = ref.watch(selectedFolderProvider);

  if (kDebugMode) {
    debugPrint('[filteredTasksProvider] Rebuilding with sortBy: $sortBy');
  }

  var filtered = tasks.where((todo) {
    if (selectedFolder != null && todo.folderId != selectedFolder) return false;
    if (selectedPriority != 'all' && todo.priority != selectedPriority) {
      return false;
    }
    if (!showCompleted && todo.isCompleted) return false;

    // Due today filter - includes both tasks due today AND overdue tasks
    if (dueTodayFilter) {
      // Tasks with no due date can't be "due today"
      if (todo.dueDate == null && todo.startDate == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Include tasks due today OR overdue (past due dates)
      final isDueToday = todo.activeOn(today);
      final isOverdue = todo.isOverdueAt(now);
      if (!isDueToday && !isOverdue) return false;
    }

    return true;
  }).toList();

  // Apply fuzzy search if there's a query
  if (searchQuery.isNotEmpty) {
    filtered = FuzzySearch.filter(
      items: filtered,
      query: searchQuery,
      getText: (todo) => '${todo.text} ${todo.notes ?? ''}',
      minSimilarity: 0.4,
    );
  }

  final secondarySortKeys = ref.watch(secondarySortKeysProvider);

  final allSortKeys = sortBy == 'manual'
      ? <String>[]
      : [sortBy, ...secondarySortKeys];

  if (kDebugMode) {
    debugPrint('[filteredTasksProvider] allSortKeys: $allSortKeys');
    debugPrint(
      '[filteredTasksProvider] Number of tasks to sort: ${filtered.length}',
    );
  }

  if (sortBy == 'manual') {
    // Keep repository-provided order for manual sort
  } else {
    filtered.sort((a, b) {
      // Always group incomplete before complete (consistent UX)
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;

      // Apply each sort key in order until we find a non-zero comparison
      for (final key in allSortKeys) {
        final cmp = _compareBySortKey(a, b, key);
        if (cmp != 0) return cmp;
      }

      // Final stable tie-breaker: createdAt descending
      return b.createdAt.compareTo(a.createdAt);
    });

    if (kDebugMode) {
      debugPrint(
        '[filteredTasksProvider] After sorting, first 3 tasks: ${filtered.take(3).map((t) => t.text).join(", ")}',
      );
    }
  }
  return filtered;
});

/// Compare two todos by a single sort key
int _compareBySortKey(Todo a, Todo b, String key) {
  int result;
  switch (key) {
    case 'date_created':
      result = b.createdAt.compareTo(a.createdAt);
      break;
    case 'date_due':
      if (a.dueDate == null && b.dueDate == null) {
        result = 0;
      } else if (a.dueDate == null) {
        result = 1;
      } else if (b.dueDate == null) {
        result = -1;
      } else {
        result = a.dueDate!.compareTo(b.dueDate!);
      }
      break;
    case 'priority':
      const order = {'high': 0, 'medium': 1, 'low': 2, 'none': 3};
      final ao = order[a.priority] ?? 2;
      final bo = order[b.priority] ?? 2;
      result = ao.compareTo(bo);
      break;
    case 'alphabetical':
      result = a.text.toLowerCase().compareTo(b.text.toLowerCase());
      break;
    default:
      result =
          0; // 'default' key has no specific order beyond completion grouping
  }
  if (key == 'alphabetical' && result != 0) {
    if (kDebugMode) {
      debugPrint(
        '[_compareBySortKey] Comparing "${a.text}" vs "${b.text}": $result',
      );
    }
  }
  return result;
}

/// Provider that checks if the search query is a valid date
final searchDateProvider = Provider<DateTime?>((ref) {
  final searchQuery = ref.watch(searchQueryProvider);
  return DateSearchParser.parseDate(searchQuery);
});

/// Provider for tasks filtered by search date
final tasksForSearchDateProvider = Provider<List<Todo>>((ref) {
  final searchDate = ref.watch(searchDateProvider);
  if (searchDate == null) return [];

  final allTasks = ref.watch(tasksProvider);
  return allTasks.where((task) {
    if (task.dueDate == null) return false;
    return DateSearchParser.isSameDay(task.dueDate!, searchDate);
  }).toList()..sort((a, b) {
    // Sort by time if available, otherwise by priority
    if (a.dueDate != null && b.dueDate != null) {
      return a.dueDate!.compareTo(b.dueDate!);
    }
    return 0;
  });
});

// ─────────────────────────────────────────────────────────────────────────
// Event filter providers
// ─────────────────────────────────────────────────────────────────────────

/// Toggle to control whether events are shown in the calendar/list views.
/// Values: 'all' | 'events_only' | 'tasks_only'
final calendarItemFilterProvider = stateProvider<String>('all');

/// Filtered events list based on search, folder, and completion filters.
final filteredEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventsProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final showCompleted = ref.watch(showCompletedProvider);
  final selectedFolder = ref.watch(selectedFolderProvider);

  var filtered = events.where((event) {
    if (selectedFolder != null && event.folderId != selectedFolder) {
      return false;
    }
    if (!showCompleted && event.isCompleted) return false;
    return true;
  }).toList();

  if (searchQuery.isNotEmpty) {
    filtered = FuzzySearch.filter(
      items: filtered,
      query: searchQuery,
      getText: (event) =>
          '${event.text} ${event.notes ?? ''} ${event.location ?? ''}',
      minSimilarity: 0.4,
    );
  }

  // Sort by start date ascending by default
  filtered.sort((a, b) {
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    return a.startDateTime.compareTo(b.startDateTime);
  });

  return filtered;
});

/// Events occurring on a specific date (for calendar day selection).
final eventsForDateProvider = Provider.family<List<Event>, DateTime>((
  ref,
  date,
) {
  final events = ref.watch(filteredEventsProvider);
  return events.where((e) => e.occursOn(date)).toList();
});

/// Provider for events filtered by search date
final eventsForSearchDateProvider = Provider<List<Event>>((ref) {
  final searchDate = ref.watch(searchDateProvider);
  if (searchDate == null) return [];

  final allEvents = ref.watch(eventsProvider);
  return allEvents.where((event) {
    return event.occursOn(searchDate);
  }).toList()..sort((a, b) {
    return a.startDateTime.compareTo(b.startDateTime);
  });
});

// ─────────────────────────────────────────────────────────────────────────
// Overdue keyword search
// ─────────────────────────────────────────────────────────────────────────

/// Whether the current search query is the keyword "overdue"
final isOverdueSearchProvider = Provider<bool>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  return query == 'overdue';
});

/// Overdue tasks (incomplete with past due date)
final overdueTasksProvider = Provider<List<Todo>>((ref) {
  if (!ref.watch(isOverdueSearchProvider)) return [];
  final now = DateTime.now();
  return ref.watch(tasksProvider).where((t) {
    return !t.isCompleted && t.isOverdueAt(now);
  }).toList()..sort(
    (a, b) => (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt),
  );
});

/// Overdue events (incomplete with past end date)
final overdueEventsProvider = Provider<List<Event>>((ref) {
  if (!ref.watch(isOverdueSearchProvider)) return [];
  final now = DateTime.now();
  return ref.watch(eventsProvider).where((e) {
    return !e.isCompleted && e.endDateTime.isBefore(now);
  }).toList()..sort((a, b) => a.endDateTime.compareTo(b.endDateTime));
});
