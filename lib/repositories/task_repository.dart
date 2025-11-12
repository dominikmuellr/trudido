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
