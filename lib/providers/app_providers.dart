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
import '../models/preferences_state.dart';
import '../models/todo.dart';
import '../repositories/task_repository.dart';
import '../services/preferences_service.dart';
import '../services/lifecycle_sync_observer.dart';
import 'clock.dart';
import '../utils/state_notifiers.dart';

/// Singleton preferences service provider.
final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => PreferencesService(),
);

/// Reactive preferences state for quick rebuilds.
final preferencesStateProvider = stateProvider<PreferencesState>(
  PreferencesState.defaultState,
);

/// Task repository provider (lazy load). Use [tasksProvider] for list.
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(),
);

class _TasksNotifier extends Notifier<List<Todo>> {
  TaskRepository get repo => ref.read(taskRepositoryProvider);

  @override
  List<Todo> build() {
    _load();
    return const [];
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

final tasksProvider = NotifierProvider<_TasksNotifier, List<Todo>>(
  _TasksNotifier.new,
);

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

/// Observer for app lifecycle and widget sync.
final lifecycleSyncObserverProvider = Provider<LifecycleSyncObserver>((ref) {
  final observer = LifecycleSyncObserver(ref);
  observer.start();
  ref.onDispose(() => observer.dispose());
  return observer;
});
