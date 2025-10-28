import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/preferences_state.dart';
import '../models/todo.dart';
import '../repositories/task_repository.dart';
import '../services/preferences_service.dart';
import 'clock.dart';

/// Singleton preferences service provider.
final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => PreferencesService(),
);

/// Reactive preferences state for quick rebuilds.
final preferencesStateProvider = StateProvider<PreferencesState>((ref) {
  final svc = ref.watch(preferencesServiceProvider);
  return svc.snapshot;
});

/// Task repository provider (lazy load). Use [tasksProvider] for list.
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(),
);

class _TasksNotifier extends StateNotifier<List<Todo>> {
  final TaskRepository repo;
  _TasksNotifier(this.repo) : super(const []) {
    _load();
  }
  Future<void> _load() async {
    await repo.load();
    state = repo.tasks;
  }

  Future<void> refresh() async {
    await repo.load();
    state = repo.tasks;
  }
}

final tasksProvider = StateNotifierProvider<_TasksNotifier, List<Todo>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return _TasksNotifier(repo);
});

/// Convenience filtered list example (incomplete tasks only).
final incompleteTasksProvider = Provider<List<Todo>>((ref) {
  final all = ref.watch(tasksProvider);
  return all.where((t) => !t.isCompleted).toList();
});

/// Tasks active today (due today OR spanning including today).
final todayActiveTasksProvider = Provider<List<Todo>>((ref) {
  final all = ref.watch(tasksProvider);
  final today = ref.watch(clockProvider).now();
  return all.where((t) => t.activeOn(today)).toList();
});

/// Guard helper turning exceptions into AsyncValue.
extension AsyncGuard on Ref {
  Future<AsyncValue<T>> guardAsync<T>(Future<T> Function() run) async {
    try {
      final value = await run();
      return AsyncValue.data(value);
    } catch (e, st) {
      return AsyncValue.error(e, st);
    }
  }
}
