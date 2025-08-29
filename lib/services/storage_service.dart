import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import '../models/category.dart';
import '../models/folder.dart';
import '../repositories/hive_folder_repository.dart';

class StorageService {
  static const String _todosBoxName = 'todos';
  static const String _categoriesBoxName = 'categories';
  
  // Deferred / lazy boxes
  static LazyBox<Todo>? _todosLazyBox; // large dataset
  static Box<Category>? _categoriesBox; // small, but also deferred to shrink critical path
  static SharedPreferences? _prefs;
  static Completer<void>? _prefsCompleter; // separate fast prefs init
  static HiveFolderRepository? _folderRepository;

  static bool _initialized = false; // core (prefs + hive init) ready
  static Completer<void>? _initCompleter; // completion for initial (settings only) init
  static Completer<void>? _todosCompleter; // completion for todos lazy box open
  static Completer<void>? _categoriesCompleter; // completion for categories box open

  // Initialize Hive and boxes
  static Future<void> init() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    final start = DateTime.now();
    await Hive.initFlutter();
    final afterHive = DateTime.now();

    // Register adapters (cheap)
    Hive.registerAdapter(TodoAdapter());
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(FolderAdapter());
    final afterAdapters = DateTime.now();

  // SharedPreferences (fast)
  await _ensurePrefs();
  final afterPrefs = DateTime.now();

    // Schedule deferred opens (categories then todos) without blocking UI.
    Future(() async {
      // Categories first (small)
      _categoriesCompleter ??= Completer<void>();
      try {
        _categoriesBox = await Hive.openBox<Category>(_categoriesBoxName);
        if (_categoriesBox!.isEmpty) await _initializeDefaultCategories();
        _categoriesCompleter?.complete();
      } catch (e, st) {
        _categoriesCompleter?.completeError(e, st);
      }
      // Todos lazy box (potentially large)
      _todosCompleter ??= Completer<void>();
      final todosStart = DateTime.now();
      try {
        _todosLazyBox = await Hive.openLazyBox<Todo>(_todosBoxName);
        _todosCompleter?.complete();
        final dur = DateTime.now().difference(todosStart).inMilliseconds;
        // ignore: avoid_print
        print('[StorageService.deferred] opened todos lazy box in ${dur}ms');
      } catch (e, st) {
        _todosCompleter?.completeError(e, st);
      }
      // Folder repo + defaults for folders (after both; not critical to initial tasks list)
      final repoStart = DateTime.now();
      try {
        _folderRepository = HiveFolderRepository();
        await _folderRepository!.init();
        final repoDur = DateTime.now().difference(repoStart).inMilliseconds;
        // ignore: avoid_print
        print('[StorageService.deferred] repo init ${repoDur}ms');
      } catch (e) {
        // ignore: avoid_print
        print('[StorageService.deferred] repo init error $e');
      }
    });
    final afterRepo = DateTime.now(); // only scheduling, not actual work

    // Lightweight timing log (debug only)
    // ignore: avoid_print
  print('[StorageService.init] hive=${afterHive.difference(start).inMilliseconds}ms adapters=${afterAdapters.difference(afterHive).inMilliseconds}ms prefs=${afterPrefs.difference(afterAdapters).inMilliseconds}ms deferredScheduled=${afterRepo.difference(afterPrefs).inMilliseconds}ms totalCritical=${afterRepo.difference(start).inMilliseconds}ms (categories,todos,repo deferred)');
    _initialized = true;
    _initCompleter!.complete();
  }

  static Future<void> ensureReady() => init();

  // Lightweight prefs-only init usable before full init (Hive) occurs.
  static Future<void> _ensurePrefs() async {
    if (_prefs != null) return;
    if (_prefsCompleter != null) return _prefsCompleter!.future;
    _prefsCompleter = Completer<void>();
    try {
      _prefs = await SharedPreferences.getInstance();
      _prefsCompleter!.complete();
    } catch (e, st) {
      _prefsCompleter!.completeError(e, st);
    }
  }

  // Fire-and-forget kick-off for early synchronous callers.
  static void kickOffPrefsInit() {
    // ignore: discarded_futures
    _ensurePrefs();
  }

  static Future<void> waitCategoriesReady() async {
    if (_categoriesBox != null) return;
    await ensureReady();
    _categoriesCompleter ??= Completer<void>(); // in case called before scheduling
    return _categoriesCompleter!.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  static Future<void> waitTodosReady() async {
    if (_todosLazyBox != null) return;
    await ensureReady();
    _todosCompleter ??= Completer<void>();
    return _todosCompleter!.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  // Getter for folder repository
  static HiveFolderRepository? get folderRepository => _folderRepository;

  static Future<void> _initializeDefaultCategories() async {
    for (final category in DefaultCategories.all) {
      await _categoriesBox!.put(category.id, category);
    }
  }

  // Todo operations
  static Future<void> saveTodo(Todo todo) async {
    await waitTodosReady();
    if (_todosLazyBox != null) { await _todosLazyBox!.put(todo.id, todo); return; }
  }

  static Future<void> deleteTodo(String id) async {
    await waitTodosReady();
    if (_todosLazyBox != null) { await _todosLazyBox!.delete(id); return; }
  }

  static Future<void> updateTodo(Todo todo) async {
    await waitTodosReady();
    if (_todosLazyBox != null) { await _todosLazyBox!.put(todo.id, todo); return; }
  }

  static List<Todo> getAllTodos() {
    // Only usable after full eager open (legacy); with lazy box this will often be empty early.
    if (_todosLazyBox != null) {
      // LazyBox has no synchronous values enumeration without IO; return empty placeholder.
      return const [];
    }
    return const [];
  }

  static Future<List<Todo>> getAllTodosAsync() async {
    await waitTodosReady();
    if (_todosLazyBox != null) {
      final keys = _todosLazyBox!.keys.cast<dynamic>().toList();
      final List<Todo> list = [];
      for (final k in keys) {
        final t = await _todosLazyBox!.get(k);
        if (t != null) list.add(t);
      }
      return list;
    }
    return const [];
  }

  static Future<Todo?> getTodoAsync(String id) async {
    await waitTodosReady();
    if (_todosLazyBox != null) return _todosLazyBox!.get(id);
    return null;
  }

  static Future<void> clearAllTodos() async {
    await waitTodosReady();
    if (_todosLazyBox != null) { await _todosLazyBox!.clear(); return; }
  }

  static Future<void> saveTodosOrder(List<Todo> todos) async {
    // Clear existing todos and save in new order
    await waitTodosReady();
    if (_todosLazyBox != null) {
      await _todosLazyBox!.clear();
      for (final t in todos) { await _todosLazyBox!.put(t.id, t); }
      return;
    }
  }

  // Category operations
  static Future<void> saveCategory(Category category) async {
    await _categoriesBox!.put(category.id, category);
  }

  static Future<void> deleteCategory(String id) async {
    await _categoriesBox!.delete(id);
  }

  static List<Category> getAllCategories() {
    return _categoriesBox!.values.toList();
  }

  static Category? getCategory(String id) {
    return _categoriesBox!.get(id);
  }

  static Future<void> clearAllCategories() async {
    await _categoriesBox!.clear();
  }

  // Settings operations using SharedPreferences
  static Future<void> setThemeMode(String mode) async {
  await _ensurePrefs();
  await _prefs!.setString('theme_mode', mode);
  }

  static String getThemeMode() {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getString('theme_mode') ?? 'system';
  }

  static Future<void> setDefaultCategory(String categoryId) async {
  await _ensurePrefs();
  await _prefs!.setString('default_category', categoryId);
  }

  static String getDefaultCategory() {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getString('default_category') ?? 'personal';
  }

  static Future<void> setDefaultPriority(String priority) async {
  await _ensurePrefs();
  await _prefs!.setString('default_priority', priority);
  }

  static String getDefaultPriority() {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getString('default_priority') ?? 'medium';
  }

  static Future<void> setLastSelectedFolder(String folderId) async {
  await _ensurePrefs();
  await _prefs!.setString('last_selected_folder', folderId);
  }

  static String? getLastSelectedFolder() {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getString('last_selected_folder');
  }

  static Future<void> saveDefaultReminderOffset(int minutes) async {
  await _ensurePrefs();
  await _prefs!.setInt('default_reminder_offset', minutes);
  }

  static int getDefaultReminderOffset() {
    // Default to 15 minutes if no setting is saved
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getInt('default_reminder_offset') ?? 15;
  }

  static Future<String> getDefaultFolderId() async {
    // First try to get the last selected folder
    final lastSelected = getLastSelectedFolder();
    if (lastSelected != null) {
      // Verify the folder still exists
      final folders = await _folderRepository!.getAllFolders();
      if (folders.any((folder) => folder.id == lastSelected)) {
        return lastSelected;
      }
    }
    
    // Fall back to 'Personal' folder or first available folder
    final folders = await _folderRepository!.getAllFolders();
    final personalFolder = folders.where((f) => f.name == 'Personal').firstOrNull;
    if (personalFolder != null) {
      return personalFolder.id;
    }
    
    // If no Personal folder, return the first folder or create a default
    if (folders.isNotEmpty) {
      return folders.first.id;
    }
    
    // This should not happen due to default folder creation, but handle it
    throw Exception('No folders available');
  }

  static Future<void> setUserName(String name) async {
  await _ensurePrefs();
  await _prefs!.setString('user_name', name);
  }

  static String getUserName() {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getString('user_name') ?? '';
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
  await _ensurePrefs();
  await _prefs!.setBool('notifications_enabled', enabled);
  }

  static bool getNotificationsEnabled() {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getBool('notifications_enabled') ?? true;
  }

  static Future<void> setAutoDeleteCompleted(bool enabled) async {
  await _ensurePrefs();
  await _prefs!.setBool('auto_delete_completed', enabled);
  }

  static bool getAutoDeleteCompleted() {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getBool('auto_delete_completed') ?? false;
  }

  static Future<void> setShowCompletedTasks(bool show) async {
  await _ensurePrefs();
  await _prefs!.setBool('show_completed_tasks', show);
  }

  static bool getShowCompletedTasks() {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getBool('show_completed_tasks') ?? true;
  }

  static Future<void> setLastAppVersion(String version) async {
  await _ensurePrefs();
  await _prefs!.setString('last_app_version', version);
  }

  static String? getLastAppVersion() {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getString('last_app_version');
  }

  // Generic meta helpers (small key-value pairs) for internal features like
  // notification action idempotency markers. Keys should be namespace prefixed.
  static String? getMeta(String key) {
  if (_prefs == null) kickOffPrefsInit();
  return _prefs?.getString('meta_$key');
  }

  static Future<void> setMeta(String key, String value) async {
  await _ensurePrefs();
  await _prefs!.setString('meta_$key', value);
  }

  // Backup and restore functionality
  static Future<Map<String, dynamic>> exportData() async {
  final todos = await getAllTodosAsync().then((l)=> l.map((todo)=> todo.toJson()).toList());
    final categories = getAllCategories().map((cat) => cat.toJson()).toList();
    
    return {
      'todos': todos,
      'categories': categories,
      'settings': {
        'theme_mode': getThemeMode(),
        'default_category': getDefaultCategory(),
        'default_priority': getDefaultPriority(),
        'notifications_enabled': getNotificationsEnabled(),
        'auto_delete_completed': getAutoDeleteCompleted(),
        'show_completed_tasks': getShowCompletedTasks(),
      },
      'exported_at': DateTime.now().toIso8601String(),
      'version': '1.0.0',
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    // Clear existing data
    await clearAllTodos();
    await _categoriesBox!.clear();
    
    // Import categories
    if (data['categories'] != null) {
      for (final categoryJson in data['categories']) {
        final category = Category.fromJson(categoryJson);
        await saveCategory(category);
      }
    }
    
    // Import todos
    if (data['todos'] != null) {
      for (final todoJson in data['todos']) {
        final todo = Todo.fromJson(todoJson);
        await saveTodo(todo);
      }
    }
    
    // Import settings
    if (data['settings'] != null) {
      final settings = data['settings'];
      await setThemeMode(settings['theme_mode'] ?? 'system');
      await setDefaultCategory(settings['default_category'] ?? 'personal');
      await setDefaultPriority(settings['default_priority'] ?? 'medium');
      await setNotificationsEnabled(settings['notifications_enabled'] ?? true);
      await setAutoDeleteCompleted(settings['auto_delete_completed'] ?? false);
      await setShowCompletedTasks(settings['show_completed_tasks'] ?? true);
    }
  }

  // Cleanup and close
  static Future<void> dispose() async {
  await _todosLazyBox?.close();
    await _categoriesBox?.close();
  }
}
