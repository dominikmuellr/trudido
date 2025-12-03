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

import 'package:meta/meta.dart';
import '../models/app_error.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';

/// Repository abstraction over StorageService for todos, enabling future
/// replacement (e.g. network sync) without touching UI providers.
class TaskRepository {
  List<Todo> _cache = const [];
  bool _loaded = false;
  bool get isLoaded => _loaded;
  void Function(List<Todo>)? _testSaveOrderHook;

  List<Todo> get tasks => _cache;

  @visibleForTesting
  void setTestTasks(List<Todo> list) {
    _cache = List<Todo>.from(list);
    _loaded = true;
  }

  @visibleForTesting
  void setTestSaveOrderHook(void Function(List<Todo>) hook) {
    _testSaveOrderHook = hook;
  }

  Future<void> load() async {
    try {
      await StorageService.waitTodosReady();
      _cache = await StorageService.getAllTodosAsync();
      _loaded = true;
    } catch (e, st) {
      throw AppError(
        AppErrorType.storageRead,
        'Failed to load tasks',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<Todo> add(Todo todo) async {
    await StorageService.saveTodo(todo);
    _cache = [..._cache, todo];
    return todo;
  }

  Future<Todo> update(Todo todo) async {
    final index = _cache.indexWhere((t) => t.id == todo.id);
    if (index == -1)
      throw const AppError(AppErrorType.notFound, 'Task not found');
    await StorageService.updateTodo(todo);
    final list = [..._cache];
    list[index] = todo;
    _cache = list;
    return todo;
  }

  Future<void> delete(String id) async {
    final before = _cache.length;
    await StorageService.deleteTodo(id);
    _cache = _cache.where((t) => t.id != id).toList();
    if (_cache.length == before) {
      throw const AppError(AppErrorType.notFound, 'Task not found');
    }
  }

  Future<void> bulkDelete(Iterable<String> ids) async {
    final set = ids.toSet();
    for (final id in set) {
      await StorageService.deleteTodo(id);
    }
    _cache = _cache.where((t) => !set.contains(t.id)).toList();
  }

  Future<void> saveOrder(List<Todo> ordered) async {
    // Persist entire ordered list (legacy storage clears & rewrites)
    await StorageService.saveTodosOrder(ordered);
    _cache = List<Todo>.from(ordered);
    _testSaveOrderHook?.call(_cache);
  }
}
