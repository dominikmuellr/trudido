import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo.dart';
import '../repositories/task_repository.dart';
import '../providers/app_providers.dart';
import '../services/notification_service.dart';
import '../models/app_error.dart';

final taskControllerProvider = StateNotifierProvider<TaskController, AsyncValue<void>>(
  (ref) => TaskController(ref),
);

class TaskController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  TaskController(this.ref) : super(const AsyncData(null));
  TaskRepository get _repo => ref.read(taskRepositoryProvider);
  final _notifications = NotificationBridge.instance;

  List<Todo> get tasks => ref.read(tasksProvider);

  Future<void> add(Todo todo) async {
    state = const AsyncLoading();
    try {
      await _repo.add(todo);
      await _scheduleNotifications(todo);
      await ref.read(tasksProvider.notifier).refresh();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> update(Todo updated) async {
    state = const AsyncLoading();
    try {
      final existing = tasks.firstWhere((t) => t.id == updated.id, orElse: () => throw const AppError(AppErrorType.notFound, 'Task not found'));
      await _cancelNotifications(existing);
      await _repo.update(updated);
      if (!updated.isCompleted) await _scheduleNotifications(updated);
      await ref.read(tasksProvider.notifier).refresh();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> toggleComplete(String id) async {
    final task = tasks.firstWhere((t) => t.id == id, orElse: () => throw const AppError(AppErrorType.notFound, 'Task not found'));
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: task.isCompleted ? null : DateTime.now(),
    );
    await update(updated);
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    try {
      final existing = tasks.firstWhere((t) => t.id == id, orElse: () => throw const AppError(AppErrorType.notFound, 'Task not found'));
      await _cancelNotifications(existing);
      await _repo.delete(id);
      await ref.read(tasksProvider.notifier).refresh();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> bulkDelete(Iterable<String> ids) async {
    state = const AsyncLoading();
    try {
      for (final id in ids) {
        try {
          final task = tasks.firstWhere((t) => t.id == id);
          await _cancelNotifications(task);
        } catch (_) {
          // ignore missing task
        }
      }
      await _repo.bulkDelete(ids);
      await ref.read(tasksProvider.notifier).refresh();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> reorder(int oldIndex, int newIndex, List<Todo> listInView) async {
  final updated = computeReordered(tasks, listInView, oldIndex, newIndex);
  if (updated == null) return;
  await _repo.saveOrder(updated);
  await ref.read(tasksProvider.notifier).refresh();
  }

  Future<void> clearCompleted() async {
    final completed = tasks.where((t) => t.isCompleted).map((e) => e.id);
    await bulkDelete(completed);
  }

  Future<void> clearAll() async {
    await bulkDelete(tasks.map((e) => e.id));
  }

  Future<void> _scheduleNotifications(Todo todo) async {
    if (todo.dueDate == null) return;
    final times = computeReminderTimes(todo.dueDate!, todo.reminderOffsetsMinutes, DateTime.now());
    for (final entry in times.entries) {
      await _notifications.scheduleTaskNotification(
        taskId: todo.id,
        title: 'Task Reminder',
        body: todo.text,
        scheduledTime: entry.value,
        uniqueKey: '${todo.id}_${entry.key}',
      );
    }
  }

  Future<void> _cancelNotifications(Todo todo) async {
    for (final offset in todo.reminderOffsetsMinutes) {
      await _notifications.cancelTaskNotification('${todo.id}_$offset');
    }
    await _notifications.cancelTaskNotification(todo.id);
  }
}

class TaskStatistics {
  final int total;
  final int completed;
  final int pending;
  final int overdue;
  final int dueToday;
  final int dueSoon;
  final double completionRate;
  final int streakDays;
  final DateTime? lastCompleted;
  final Map<String,int> byCategory;
  final Map<String,int> byPriority;
  const TaskStatistics({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.dueToday,
    required this.dueSoon,
    required this.completionRate,
    required this.streakDays,
    required this.lastCompleted,
    required this.byCategory,
    required this.byPriority,
  });

  String get motivationalMessage {
    if (completionRate >= 0.8) {
      return "Excellent work! You're crushing your goals! 🎉";
    } else if (completionRate >= 0.6) {
      return "Great progress! Keep up the momentum! 💪";
    } else if (completionRate >= 0.4) {
      return "You're making steady progress! 📈";
    } else if (completionRate > 0) {
      return "Every step counts! Keep going! 🌟";
    } else {
      return "Ready to start your productive journey? 🚀";
    }
  }
}

/// Exposed indirection for statistics & derived selectors. Override in tests
/// instead of overriding the private tasks notifier.
final rawTasksProvider = Provider<List<Todo>>((ref) => ref.watch(tasksProvider));

/// Pure helper to compute a new ordered list given the full task list, a
/// visible subset (in the same order), and the drag indices from that view.
/// Returns null if indices are invalid.
List<Todo>? computeReordered(List<Todo> full, List<Todo> view, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= view.length) return null;
  // ReorderableListView gives newIndex that is the target position accounting for removal.
  // If dragged to the end, newIndex can equal view.length.
  final adjustedNewIndex = (newIndex > view.length) ? view.length : newIndex;
  final fullCopy = List<Todo>.from(full);
  // Identify the item being moved.
  final moving = view[oldIndex];
  final oldFullPos = fullCopy.indexWhere((t) => t.id == moving.id);
  if (oldFullPos == -1) return null;
  fullCopy.removeAt(oldFullPos);
  int insertPos;
  if (adjustedNewIndex >= view.length) {
    // Move to end of sequence.
    insertPos = fullCopy.length;
  } else {
    final target = view[adjustedNewIndex >= view.length ? view.length - 1 : adjustedNewIndex];
    // After removal, find the target position in the shrunk list.
    insertPos = fullCopy.indexWhere((t) => t.id == target.id);
    if (insertPos == -1) insertPos = fullCopy.length;
  }
  fullCopy.insert(insertPos, moving);
  return fullCopy;
}

/// Returns a map of offsetMinutes -> scheduled DateTime for future reminders.
/// Filters out any times that would be in the past relative to [now] and
/// de-duplicates offsets. Result is sorted by scheduled time ascending.
Map<int, DateTime> computeReminderTimes(DateTime due, Iterable<int> offsetsMinutes, DateTime now) {
  final map = <int, DateTime>{};
  for (final raw in offsetsMinutes.toSet()) {
    if (raw < 0) continue; // ignore negative offsets
    final when = due.subtract(Duration(minutes: raw));
    if (when.isAfter(now)) {
      map[raw] = when;
    }
  }
  final entries = map.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return {for (final e in entries) e.key: e.value};
}

final taskStatisticsProvider = Provider<TaskStatistics>((ref) {
  final tasks = ref.watch(rawTasksProvider);
  final total = tasks.length;
  final completed = tasks.where((t) => t.isCompleted).length;
  final pending = total - completed;
  final now = DateTime.now();
  int overdue = 0, dueToday = 0, dueSoon = 0;
  for (final t in tasks) {
    final due = t.dueDate;
    if (due == null || t.isCompleted) {
      continue;
    }
    if (now.isAfter(due)) {
      overdue++;
    } else if (due.year == now.year && due.month == now.month && due.day == now.day) {
      dueToday++;
    } else if (due.difference(now).inDays >= 0 && due.difference(now).inDays <= 3) {
      dueSoon++;
    }
  }
  final completionRate = total == 0 ? 0.0 : completed / total;
  final completedDates = tasks
      .where((t) => t.isCompleted && t.completedAt != null)
      .map((t) => DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  int streak = 0;
  DateTime cursor = DateTime(now.year, now.month, now.day);
  for (final d in completedDates) {
    if (d == cursor || d == cursor.subtract(const Duration(days: 1))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }
  final lastCompleted = tasks
      .where((t) => t.completedAt != null)
      .map((t) => t.completedAt!)
      .fold<DateTime?>(null, (prev, e) => prev == null || e.isAfter(prev) ? e : prev);
  final cat = <String,int>{};
  final pri = <String,int>{};
  for (final t in tasks) {
    cat[t.category] = (cat[t.category] ?? 0) + 1;
    pri[t.priority] = (pri[t.priority] ?? 0) + 1;
  }
  return TaskStatistics(
    total: total,
    completed: completed,
    pending: pending,
    overdue: overdue,
    dueToday: dueToday,
    dueSoon: dueSoon,
    completionRate: completionRate,
    streakDays: streak,
    lastCompleted: lastCompleted,
    byCategory: cat,
    byPriority: pri,
  );
});
