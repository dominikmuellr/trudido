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

// View state providers
enum TaskViewType { list, calendar }

final taskViewTypeProvider = StateProvider<TaskViewType>(
  (ref) => TaskViewType.list,
);
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

    // Due today filter
    if (dueTodayFilter) {
      if (todo.dueDate == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final taskDate = DateTime(
        todo.dueDate!.year,
        todo.dueDate!.month,
        todo.dueDate!.day,
      );
      if (!taskDate.isAtSameMomentAs(today)) return false;
    }

    return true;
  }).toList();

  switch (sortBy) {
    case 'date_created':
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case 'date_due':
      filtered.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
      break;
    case 'priority':
      const order = {'high': 0, 'medium': 1, 'low': 2};
      filtered.sort((a, b) {
        final ao = order[a.priority] ?? 1;
        final bo = order[b.priority] ?? 1;
        return ao.compareTo(bo);
      });
      break;
    case 'alphabetical':
      filtered.sort(
        (a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()),
      );
      break;
    case 'manual':
      // Keep repository-provided order
      break;
    default:
      filtered.sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }
  return filtered;
});
