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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import 'app_providers.dart';
import '../services/folder_provider.dart';
import '../widgets/calendar_view.dart';

// Filter state providers
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedPriorityProvider = StateProvider<String>((ref) => 'all');
final showCompletedProvider = StateProvider<bool>((ref) => true);
final sortByProvider = StateProvider<String>(
  (ref) => 'default',
); // default|date_created|date_due|priority|alphabetical|manual
final dueTodayFilterProvider = StateProvider<bool>((ref) => false);

/// Secondary sort keys for multi-sort. Primary sort is sortByProvider.
/// Example: ['alphabetical'] means sort by primary first, then alphabetical.
final secondarySortKeysProvider = StateProvider<List<String>>((ref) => []);

// View state providers
enum TaskViewType { list, calendar }

final taskViewTypeProvider = StateProvider<TaskViewType>((ref) {
  final defaultView = ref.watch(preferencesStateProvider).defaultTaskView;
  return defaultView == 'calendar' ? TaskViewType.calendar : TaskViewType.list;
});
final selectedCalendarDateProvider = StateProvider<DateTime?>((ref) => null);

// Calendar format notifier with persistence
class CalendarFormatNotifier extends StateNotifier<CustomCalendarFormat> {
  CalendarFormatNotifier() : super(CustomCalendarFormat.month) {
    _loadSavedFormat();
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
      // If loading fails, keep default (month)
    }
  }

  Future<void> setFormat(CustomCalendarFormat format) async {
    state = format;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('calendar_format_index', format.index);
    } catch (e) {
      // Save failed, but state is updated locally
    }
  }
}

final calendarFormatProvider =
    StateNotifierProvider<CalendarFormatNotifier, CustomCalendarFormat>(
      (ref) => CalendarFormatNotifier(),
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
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      if (!todo.text.toLowerCase().contains(q) &&
          !(todo.notes?.toLowerCase().contains(q) ?? false))
        return false;
    }
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

  // Get secondary sort keys for multi-sort
  final secondarySortKeys = ref.watch(secondarySortKeysProvider);

  // Build list of all sort keys: primary + secondary
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
