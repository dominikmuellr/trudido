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

/// Manages UI filtering state for tasks and notes (search, sort, view mode).
/// These providers control what the user sees in task/note lists.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import '../utils/date_search_parser.dart';
import 'app_providers.dart';
import '../services/folder_provider.dart';
import '../widgets/calendar_view.dart';
import '../utils/state_notifiers.dart';

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

  var filtered = tasks.where((todo) {
    if (selectedFolder != null && todo.folderId != selectedFolder) return false;
    if (selectedPriority != 'all' && todo.priority != selectedPriority)
      return false;
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
  }
  return filtered;
});

/// Compare two todos by a single sort key
int _compareBySortKey(Todo a, Todo b, String key) {
  switch (key) {
    case 'date_created':
      return b.createdAt.compareTo(a.createdAt);
    case 'date_due':
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    case 'priority':
      const order = {'high': 0, 'medium': 1, 'low': 2, 'none': 3};
      final ao = order[a.priority] ?? 2;
      final bo = order[b.priority] ?? 2;
      return ao.compareTo(bo);
    case 'alphabetical':
      return a.text.toLowerCase().compareTo(b.text.toLowerCase());
    default:
      return 0; // 'default' key has no specific order beyond completion grouping
  }
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
