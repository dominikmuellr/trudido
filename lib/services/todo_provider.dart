import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo.dart';
import '../models/category.dart';
import '../models/statistics.dart';
import '../services/storage_service.dart';
import '../services/folder_provider.dart';
import '../services/notification_service.dart';

// Provider for all todos
final todosProvider = StateNotifierProvider<TodosNotifier, List<Todo>>((ref) {
  return TodosNotifier();
});

// Provider for all categories
final categoriesProvider = StateNotifierProvider<CategoriesNotifier, List<Category>>((ref) {
  return CategoriesNotifier();
});

// Provider for filtered todos based on current filters
final filteredTodosProvider = Provider<List<Todo>>((ref) {
  final todos = ref.watch(todosProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final selectedPriority = ref.watch(selectedPriorityProvider);
  final selectedFolder = ref.watch(selectedFolderProvider);
  final showCompleted = ref.watch(showCompletedProvider);
  final sortBy = ref.watch(sortByProvider);

  var filtered = todos.where((todo) {
    // Search filter
    if (searchQuery.isNotEmpty && 
        !todo.text.toLowerCase().contains(searchQuery.toLowerCase()) &&
        !(todo.notes?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false)) {
      return false;
    }
    
    // Category filter
    if (selectedCategory != 'all' && todo.category != selectedCategory) {
      return false;
    }
    
    // Folder filter
    if (selectedFolder != null && todo.folderId != selectedFolder) {
      return false;
    }
    
    // Priority filter
    if (selectedPriority != 'all' && todo.priority != selectedPriority) {
      return false;
    }
    
    // Completed filter
    if (!showCompleted && todo.isCompleted) {
      return false;
    }
    
    return true;
  }).toList();

  // Sort todos
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
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      filtered.sort((a, b) {
        final aOrder = priorityOrder[a.priority] ?? 1;
        final bOrder = priorityOrder[b.priority] ?? 1;
        return aOrder.compareTo(bOrder);
      });
      break;
    case 'alphabetical':
      filtered.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
      break;
    case 'manual':
      // Keep the manual order from storage - no sorting
      break;
    default:
      // Default: incomplete first, then by creation date
      filtered.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  return filtered;
});

// Provider for todo statistics
final statisticsProvider = Provider<TodoStatistics>((ref) {
  final todos = ref.watch(todosProvider);
  
  final totalTasks = todos.length;
  final completedTasks = todos.where((todo) => todo.isCompleted).length;
  final pendingTasks = totalTasks - completedTasks;
  final overdueTasks = todos.where((todo) => todo.isOverdue).length;
  final dueTodayTasks = todos.where((todo) => todo.isDueToday).length;
  final dueSoonTasks = todos.where((todo) => todo.isDueSoon).length;
  
  final tasksByCategory = <String, int>{};
  final tasksByPriority = <String, int>{};
  
  for (final todo in todos) {
    tasksByCategory[todo.category] = (tasksByCategory[todo.category] ?? 0) + 1;
    tasksByPriority[todo.priority] = (tasksByPriority[todo.priority] ?? 0) + 1;
  }
  
  final completionRate = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
  
  // Calculate streak (simplified - consecutive days with completed tasks)
  final streakDays = _calculateStreak(todos);
  final lastCompletedDate = _getLastCompletedDate(todos);
  
  return TodoStatistics(
    totalTasks: totalTasks,
    completedTasks: completedTasks,
    pendingTasks: pendingTasks,
    overdueTasks: overdueTasks,
    dueTodayTasks: dueTodayTasks,
    dueSoonTasks: dueSoonTasks,
    tasksByCategory: tasksByCategory,
    tasksByPriority: tasksByPriority,
    completionRate: completionRate,
    streakDays: streakDays,
    lastCompletedDate: lastCompletedDate,
  );
});

// Filter providers
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String>((ref) => 'all');
final selectedPriorityProvider = StateProvider<String>((ref) => 'all');
final showCompletedProvider = StateProvider<bool>((ref) => true);
final sortByProvider = StateProvider<String>((ref) => 'default');

// Settings providers
final themeProvider = StateProvider<String>((ref) => StorageService.getThemeMode());
final defaultCategoryProvider = StateProvider<String>((ref) => StorageService.getDefaultCategory());
final defaultPriorityProvider = StateProvider<String>((ref) => StorageService.getDefaultPriority());

// Todos state notifier
class TodosNotifier extends StateNotifier<List<Todo>> {
  TodosNotifier() : super([]) {
  _init();
  }

  final _notificationBridge = NotificationBridge.instance;

  bool _loading = true;
  bool get isLoading => _loading;

  Future<void> _init() async {
  await StorageService.waitTodosReady();
  state = await StorageService.getAllTodosAsync();
    _loading = false;
  }

  Future<void> addTodo(Todo todo) async {
    await StorageService.saveTodo(todo);
    state = [...state, todo];

    // Schedule notifications for the new task if it has a due date
    if (todo.dueDate != null) {
      await _scheduleNotificationsForTask(todo);
    }
  }

  Future<void> updateTodo(Todo updatedTodo) async {
    // Fetch the original task directly from storage to avoid race conditions
  final originalTodo = await StorageService.getTodoAsync(updatedTodo.id);
  if (originalTodo == null) {
      // If task doesn't exist, do nothing.
      return;
    }

    await StorageService.updateTodo(updatedTodo);
    state = [
      for (final todo in state)
        if (todo.id == updatedTodo.id) updatedTodo else todo,
    ];

    // Cancel all old notifications and schedule all new ones
    await _handleNotificationUpdate(originalTodo, updatedTodo);
  }

  Future<void> deleteTodo(String id) async {
    // Find the task before deleting it to cancel its notifications
    final todoToDelete = state.firstWhere((todo) => todo.id == id);
    await _cancelNotificationsForTask(todoToDelete);

    await StorageService.deleteTodo(id);
    state = state.where((todo) => todo.id != id).toList();
  }

  Future<void> toggleTodo(String id) async {
    // Fetch the task directly from storage to avoid race conditions
  final originalTodo = await StorageService.getTodoAsync(id);
  if (originalTodo == null) {
      // If task doesn't exist, do nothing.
      return;
    }

    final updatedTodo = originalTodo.copyWith(
      isCompleted: !originalTodo.isCompleted,
      completedAt: !originalTodo.isCompleted ? DateTime.now() : null,
    );

    // The call to updateTodo will handle all notification logic
    await updateTodo(updatedTodo);
  }

  Future<void> deleteCompleted() async {
    final completedTodos = state.where((todo) => todo.isCompleted).toList();
    for (final todo in completedTodos) {
      // No need to cancel notifications, as completed tasks should already have them cancelled.
      await StorageService.deleteTodo(todo.id);
    }
    state = state.where((todo) => !todo.isCompleted).toList();
  }

  /// A robust method to cancel all old notifications and schedule all new ones.
  Future<void> _handleNotificationUpdate(Todo originalTodo, Todo updatedTodo) async {
    // First, cancel all notifications that might have existed for the original task
    await _cancelNotificationsForTask(originalTodo);

    // Then, if the updated task is not completed, schedule all new notifications
    if (!updatedTodo.isCompleted) {
      await _scheduleNotificationsForTask(updatedTodo);
    }
  }

  /// Helper method to schedule notifications for a task
  Future<void> _scheduleNotificationsForTask(Todo todo) async {
    if (todo.dueDate != null) {
      debugPrint('TodoProvider: Scheduling notifications for task: ${todo.text}');
      debugPrint('TodoProvider: Due date: ${todo.dueDate}');
      debugPrint('TodoProvider: Reminder offsets: ${todo.reminderOffsetsMinutes}');
      
      // Calculate notification times based on reminder offsets
      for (final offsetMinutes in todo.reminderOffsetsMinutes) {
        final notificationTime = todo.dueDate!.subtract(Duration(minutes: offsetMinutes));
        
        // Only schedule if the notification time is in the future
        if (notificationTime.isAfter(DateTime.now())) {
          final uniqueKey = '${todo.id}_$offsetMinutes';
          debugPrint('TodoProvider: Scheduling notification key $uniqueKey for $notificationTime');
          await _notificationBridge.scheduleTaskNotification(
            taskId: todo.id,
            title: 'Task Reminder',
            body: todo.text,
            scheduledTime: notificationTime,
            uniqueKey: uniqueKey,
          );
        }
      }
    }
  }

  /// Helper method to cancel notifications for a task
  Future<void> _cancelNotificationsForTask(Todo todo) async {
    // Cancel notifications for all reminder offsets using their unique keys
    for (final offsetMinutes in todo.reminderOffsetsMinutes) {
      await _notificationBridge.cancelTaskNotification('${todo.id}_$offsetMinutes');
    }
    // Also attempt legacy single ID cancel for backward compatibility
    await _notificationBridge.cancelTaskNotification(todo.id);
  }

  // --- Other methods like reorderTodos, clearAll, etc. remain the same ---

  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    final todos = [...state];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final todo = todos.removeAt(oldIndex);
    todos.insert(newIndex, todo);
    state = todos;
    await StorageService.saveTodosOrder(todos);
  }

  Future<void> clearAllData() async {
    await StorageService.clearAllTodos();
    await StorageService.clearAllCategories();
    state = [];
  }
}

// Categories state notifier
class CategoriesNotifier extends StateNotifier<List<Category>> {
  CategoriesNotifier() : super([]) {
  _init();
  }

  bool _loading = true;
  bool get isLoading => _loading;

  Future<void> _init() async {
  await StorageService.waitCategoriesReady();
  state = StorageService.getAllCategories();
    _loading = false;
  }

  Future<void> addCategory(Category category) async {
    await StorageService.saveCategory(category);
    state = [...state, category];
  }

  Future<void> updateCategory(Category updatedCategory) async {
    await StorageService.saveCategory(updatedCategory);
    state = [
      for (final category in state)
        if (category.id == updatedCategory.id) updatedCategory else category,
    ];
  }

  Future<void> deleteCategory(String id) async {
    await StorageService.deleteCategory(id);
    state = state.where((category) => category.id != id).toList();
  }
}

// Helper functions
int _calculateStreak(List<Todo> todos) {
  if (todos.isEmpty) return 0;
  
  final completedTodos = todos
      .where((todo) => todo.isCompleted && todo.completedAt != null)
      .toList();
  
  if (completedTodos.isEmpty) return 0;
  
  // Group by date and count consecutive days
  final completedDates = completedTodos
      .map((todo) => DateTime(
            todo.completedAt!.year,
            todo.completedAt!.month,
            todo.completedAt!.day,
          ))
      .toSet()
      .toList();
  
  completedDates.sort((a, b) => b.compareTo(a));
  
  int streak = 0;
  DateTime currentDate = DateTime.now();
  currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
  
  for (final date in completedDates) {
    if (date.isAtSameMomentAs(currentDate) || 
        date.isAtSameMomentAs(currentDate.subtract(const Duration(days: 1)))) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }
  
  return streak;
}

DateTime? _getLastCompletedDate(List<Todo> todos) {
  final completedTodos = todos
      .where((todo) => todo.isCompleted && todo.completedAt != null)
      .toList();
  
  if (completedTodos.isEmpty) return null;
  
  completedTodos.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  return completedTodos.first.completedAt;
}
