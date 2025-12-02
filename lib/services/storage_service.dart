import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import '../models/folder.dart';
import '../models/folder_template.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../repositories/hive_folder_repository.dart';
import '../repositories/hive_folder_template_repository.dart';

class StorageService {
  static const String _todosBoxName = 'todos';
  static const String _notesBoxName = 'notes';
  static const String _noteFoldersBoxName = 'note_folders';

  // Deferred / lazy boxes
  static LazyBox<Todo>? _todosLazyBox; // large dataset
  static Box<Note>? _notesBox; // notes storage
  static Box<NoteFolder>? _noteFoldersBox; // note folders storage
  static SharedPreferences? _prefs;
  static Completer<void>? _prefsCompleter; // separate fast prefs init
  // Exposed readiness flag so preference notifiers can avoid redundant async reloads.
  static bool get prefsReady => _prefs != null;
  static HiveFolderRepository? _folderRepository;
  static HiveFolderTemplateRepository? _templateRepository;
  // Toggle for console logging (timings, deferred open). Disable in tests for cleaner output.
  static bool enableLogging = true;

  /// When true, deferred opens (notes/todos/folders) will run synchronously
  /// inside `init()` instead of being scheduled in a microtask. This helps
  /// widget tests avoid background timers and pending futures. Tests should
  /// set `StorageService.performDeferredSynchronously = true` in setUpAll if
  /// they call `StorageService.init()` and expect no background timers.
  static bool performDeferredSynchronously = false;

  static bool _initialized = false; // core (prefs + hive init) ready
  static Completer<void>?
  _initCompleter; // completion for initial (settings only) init
  static Completer<void>? _todosCompleter; // completion for todos lazy box open
  static Completer<void>? _notesCompleter; // completion for notes box open
  static Completer<void>?
  _noteFoldersCompleter; // completion for note folders box open

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
    // CategoryAdapter removed - categories system eliminated
    Hive.registerAdapter(FolderAdapter());
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(NoteFolderAdapter());
    // Register template adapters if they exist
    try {
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(FolderTemplateAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(TaskTemplateAdapter());
      }
    } catch (e) {
      // Template adapters not generated yet, will work when they are
      if (enableLogging) {
        debugPrint('[StorageService] Template adapters not ready: $e');
      }
    }
    final afterAdapters = DateTime.now();

    // SharedPreferences (fast)
    await _ensurePrefs();
    final afterPrefs = DateTime.now();

    // Schedule or run deferred opens (todos and notes) without blocking UI.
    FutureOr<void> runDeferred() async {
      // Note folders box MUST open first (needed for note encryption/decryption)
      _noteFoldersCompleter ??= Completer<void>();
      try {
        _noteFoldersBox = await Hive.openBox<NoteFolder>(_noteFoldersBoxName);
        // Initialize default vault folder if this is first run
        await _initializeDefaultVaultFolder();
        _noteFoldersCompleter?.complete();
        if (enableLogging) {
          debugPrint('[StorageService] Note folders box opened successfully');
        }
      } catch (e) {
        if (enableLogging) {
          debugPrint(
            '[StorageService] Failed to initialize note folders box: $e',
          );
        }
        // Attempt recovery by deleting and recreating the box
        try {
          await Hive.deleteBoxFromDisk(_noteFoldersBoxName);
          _noteFoldersBox = await Hive.openBox<NoteFolder>(_noteFoldersBoxName);
          await _initializeDefaultVaultFolder();
          _noteFoldersCompleter?.complete();
          if (enableLogging) {
            debugPrint(
              '[StorageService] Successfully recovered note folders box',
            );
          }
        } catch (recoveryError) {
          _noteFoldersCompleter?.completeError(recoveryError);
          if (enableLogging) {
            debugPrint(
              '[StorageService] Failed to recover note folders box: $recoveryError',
            );
          }
        }
      }

      // Notes box (small to medium) - opened AFTER folders
      _notesCompleter ??= Completer<void>();
      try {
        _notesBox = await Hive.openBox<Note>(_notesBoxName);
        if (_notesBox!.isEmpty) await _initializeDefaultNote();
        _notesCompleter?.complete();
      } catch (e) {
        if (enableLogging) {
          debugPrint('[StorageService] Failed to initialize notes box: $e');
          debugPrint(
            '[StorageService] Attempting to recover by clearing corrupted data...',
          );
        }

        // Try to recover by deleting the corrupted box
        try {
          await Hive.deleteBoxFromDisk(_notesBoxName);
          _notesBox = await Hive.openBox<Note>(_notesBoxName);
          await _initializeDefaultNote();
          _notesCompleter?.complete();
          if (enableLogging) {
            debugPrint('[StorageService] Successfully recovered notes box');
          }
        } catch (recoveryError, recoverySt) {
          _notesCompleter?.completeError(recoveryError, recoverySt);
          if (enableLogging) {
            debugPrint(
              '[StorageService] Failed to recover notes box: $recoveryError',
            );
          }
        }
      }

      // Todos lazy box (potentially large)
      _todosCompleter ??= Completer<void>();
      final todosStart = DateTime.now();
      try {
        _todosLazyBox = await Hive.openLazyBox<Todo>(_todosBoxName);
        _todosCompleter?.complete();
        final dur = DateTime.now().difference(todosStart).inMilliseconds;
        if (enableLogging) {
          // ignore: avoid_debugPrint
          debugPrint(
            '[StorageService.deferred] opened todos lazy box in ${dur}ms',
          );
        }
      } catch (e, st) {
        _todosCompleter?.completeError(e, st);
      }
      // Folder repo + defaults for folders (after both; not critical to initial tasks list)
      final repoStart = DateTime.now();
      try {
        _folderRepository = HiveFolderRepository();
        await _folderRepository!.init();

        // Initialize template repository
        _templateRepository = HiveFolderTemplateRepository();
        await _templateRepository!.init();

        final repoDur = DateTime.now().difference(repoStart).inMilliseconds;
        if (enableLogging) {
          // ignore: avoid_debugPrint
          debugPrint('[StorageService.deferred] repo init ${repoDur}ms');
        }
      } catch (e) {
        if (enableLogging) {
          // ignore: avoid_debugPrint
          debugPrint('[StorageService.deferred] repo init error $e');
        }
      }
    }

    if (performDeferredSynchronously) {
      // Run inline for tests to avoid scheduling background timers that
      // the test harness will complain about.
      await runDeferred();
    } else {
      Future(() async => await runDeferred());
    }
    final afterRepo = DateTime.now(); // only scheduling, not actual work

    // Lightweight timing log (debug only)
    if (enableLogging) {
      // ignore: avoid_debugPrint
      debugPrint(
        '[StorageService.init] hive=${afterHive.difference(start).inMilliseconds}ms adapters=${afterAdapters.difference(afterHive).inMilliseconds}ms prefs=${afterPrefs.difference(afterAdapters).inMilliseconds}ms deferredScheduled=${afterRepo.difference(afterPrefs).inMilliseconds}ms totalCritical=${afterRepo.difference(start).inMilliseconds}ms (categories,todos,repo deferred)',
      );
    }
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

  // Public awaitable prefs readiness (only loads SharedPreferences)
  static Future<void> ensurePrefs() => _ensurePrefs();

  static Future<void> waitTodosReady() async {
    if (_todosLazyBox != null) return;
    await ensureReady();
    _todosCompleter ??= Completer<void>();
    return _todosCompleter!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {},
    );
  }

  static Future<void> waitNotesReady() async {
    if (_notesBox != null) return;
    await ensureReady();
    _notesCompleter ??= Completer<void>();
    return _notesCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
  }

  // Getter for folder repository
  static HiveFolderRepository? get folderRepository => _folderRepository;

  static Future<void> _initializeDefaultNote() async {
    final welcomeNote = Note(
      title: 'Welcome to Notes',
      content:
          '''# Welcome to Notes!\n\nCreate rich, beautiful notes with our powerful editor. You can:\n\n## Quick Formatting
- Use the **toolbar** for visual formatting
- Or type **markdown shortcuts** (# for headers, ** for bold, * for italic)
- Press **/** to add media, voice recordings, links, and code blocks

## Media Support
📸 Add photos from gallery or camera
🎥 Embed videos
🎤 Record voice notes
🔗 Insert links

## Markdown Shortcuts
Type these and press space:
- # → Heading 1
- ## → Heading 2  
- - → Bullet list
- 1. → Numbered list
- [ ] → Checkbox
- > → Block quote

## Rich Formatting
- **Bold**, *Italic*, Underline, ~~Strikethrough~~
- Different font sizes and colors
- Code blocks and inline code
- Lists, checkboxes, and quotes

**Tap the + button to create your first note!**

Happy note-taking! ✨''',
    );
    await _notesBox!.put(welcomeNote.id, welcomeNote);
  }

  static Future<void> _initializeDefaultVaultFolder() async {
    if (_noteFoldersBox == null) return;

    // Check if we already have folders
    if (_noteFoldersBox!.isNotEmpty) return;

    // Create the default Vault folder
    final vaultFolder = NoteFolder(
      name: 'Vault',
      description: 'Secure encrypted folder for private notes',
      isVault: true,
      hasPassword: false, // No password set initially
      useBiometric: true,
      sortOrder: 0,
    );
    await _noteFoldersBox!.put(vaultFolder.id, vaultFolder);

    if (enableLogging) {
      debugPrint('[StorageService] Created default Vault folder');
    }
  }

  // Todo operations
  static Future<void> saveTodo(Todo todo) async {
    await waitTodosReady();
    try {
      if (_todosLazyBox == null) {
        // Attempt to open the lazy box now as a last resort
        _todosLazyBox = await Hive.openLazyBox<Todo>(_todosBoxName);
      }
      if (_todosLazyBox != null) {
        await _todosLazyBox!.put(todo.id, todo);
        return;
      }
      throw Exception('Todos lazy box is not available');
    } catch (e, st) {
      debugPrint('[StorageService] saveTodo failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> deleteTodo(String id) async {
    await waitTodosReady();
    try {
      if (_todosLazyBox == null) {
        _todosLazyBox = await Hive.openLazyBox<Todo>(_todosBoxName);
      }
      if (_todosLazyBox != null) {
        await _todosLazyBox!.delete(id);
        return;
      }
      throw Exception('Todos lazy box is not available');
    } catch (e, st) {
      debugPrint('[StorageService] deleteTodo failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> updateTodo(Todo todo) async {
    await waitTodosReady();
    try {
      if (_todosLazyBox == null) {
        _todosLazyBox = await Hive.openLazyBox<Todo>(_todosBoxName);
      }
      if (_todosLazyBox != null) {
        await _todosLazyBox!.put(todo.id, todo);
        return;
      }
      throw Exception('Todos lazy box is not available');
    } catch (e, st) {
      debugPrint('[StorageService] updateTodo failed: $e\n$st');
      rethrow;
    }
  }

  static List<Todo> getAllTodos() {
    // Only usable after full eager open (legacy); with lazy box this will often be empty early.
    if (_todosLazyBox != null) {
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
    if (_todosLazyBox != null) {
      await _todosLazyBox!.clear();
      return;
    }
  }

  static Future<void> saveTodosOrder(List<Todo> todos) async {
    // Clear todos and save in new order
    await waitTodosReady();
    if (_todosLazyBox != null) {
      await _todosLazyBox!.clear();
      for (final t in todos) {
        await _todosLazyBox!.put(t.id, t);
      }
      return;
    }
  }

  // Notes operations
  static Future<void> saveNote(Note note) async {
    if (_notesBox == null) return;
    await _notesBox!.put(note.id, note);
  }

  static Future<void> deleteNote(String id) async {
    if (_notesBox == null) return;
    await _notesBox!.delete(id);
  }

  static List<Note> getAllNotes() {
    if (_notesBox == null) return const [];
    return _notesBox!.values.toList();
  }

  static Note? getNote(String id) {
    if (_notesBox == null) return null;
    return _notesBox!.get(id);
  }

  static Future<void> clearAllNotes() async {
    if (_notesBox == null) return;
    await _notesBox!.clear();
  }

  // Note folders operations
  static Future<void> saveNoteFolder(NoteFolder folder) async {
    if (_noteFoldersBox == null) return;
    await _noteFoldersBox!.put(folder.id, folder);
  }

  static Future<void> deleteNoteFolder(String id) async {
    if (_noteFoldersBox == null) return;
    await _noteFoldersBox!.delete(id);
  }

  static List<NoteFolder> getAllNoteFolders() {
    if (_noteFoldersBox == null) return const [];
    return _noteFoldersBox!.values.toList();
  }

  static NoteFolder? getNoteFolder(String id) {
    if (_noteFoldersBox == null) return null;
    return _noteFoldersBox!.get(id);
  }

  static Future<void> waitNoteFoldersReady() async {
    // Wait specifically for note folders completer
    _noteFoldersCompleter ??= Completer<void>();
    return _noteFoldersCompleter!.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Note folders box failed to open in time');
      },
    );
  }

  static Future<void> clearAllNoteFolders() async {
    if (_noteFoldersBox == null) return;
    await _noteFoldersBox!.clear();
  }

  // Theme and preferences operations

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
    final personalFolder = folders
        .where((f) => f.name == 'Personal')
        .firstOrNull;
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

  // AMOLED / pure black dark theme preference
  static Future<void> setUseBlackTheme(bool value) async {
    await _ensurePrefs();
    await _prefs!.setBool('use_black_theme', value);
  }

  static bool getUseBlackTheme() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getBool('use_black_theme') ?? false;
  }

  // Dynamic color (Material You) preference
  static Future<void> setUseDynamicColor(bool value) async {
    await _ensurePrefs();
    await _prefs!.setBool('use_dynamic_color', value);
  }

  static bool getUseDynamicColor() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getBool('use_dynamic_color') ??
        true; // default ON on capable devices
  }

  // Compact density preference
  static Future<void> setCompactDensity(bool value) async {
    await _ensurePrefs();
    await _prefs!.setBool('compact_density', value);
  }

  static bool getCompactDensity() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getBool('compact_density') ?? false;
  }

  // High contrast preference
  static Future<void> setHighContrast(bool value) async {
    await _ensurePrefs();
    await _prefs!.setBool('high_contrast', value);
  }

  static bool getHighContrast() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getBool('high_contrast') ?? false;
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
    try {
      debugPrint('[StorageService] Starting export process...');

      final todos = await getAllTodosAsync().then(
        (l) => l.map((todo) => todo.toJson()).toList(),
      );

      // Export notes
      await waitNotesReady();
      final notes = getAllNotes().map((note) => note.toJson()).toList();

      // Export folders
      final folders = _folderRepository != null
          ? (await _folderRepository!.getAllFolders())
                .map((folder) => folder.toJson())
                .toList()
          : <Map<String, dynamic>>[];

      // Export templates (both built-in and custom)
      final templates = _templateRepository != null
          ? (await _templateRepository!.getAllTemplates())
                .map((template) => template.toJson())
                .toList()
          : <Map<String, dynamic>>[];

      debugPrint(
        '[StorageService] Exporting ${todos.length} todos, ${notes.length} notes, ${folders.length} folders, and ${templates.length} templates',
      );

      final exportMap = {
        'todos': todos,
        'notes': notes,
        'folders': folders,
        'templates': templates,
        'settings': {
          'theme_mode': getThemeMode(),
          'default_category': getDefaultCategory(),
          'default_priority': getDefaultPriority(),
          'notifications_enabled': getNotificationsEnabled(),
          'auto_delete_completed': getAutoDeleteCompleted(),
          'show_completed_tasks': getShowCompletedTasks(),
        },
        'exported_at': DateTime.now().toIso8601String(),
        'version': '1.2.2', // Version for v1.2.2 release
      };

      debugPrint('[StorageService] Export data prepared successfully');
      return exportMap;
    } catch (e, stackTrace) {
      debugPrint('[StorageService] Export failed: $e');
      debugPrint('[StorageService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // FAB position (left | center | right) preference
  static Future<void> setFabPosition(String position) async {
    if (position != 'left' && position != 'center' && position != 'right')
      return;
    await _ensurePrefs();
    await _prefs!.setString('fab_position', position);
  }

  static String getFabPosition() {
    if (_prefs == null) kickOffPrefsInit();
    final v = _prefs?.getString('fab_position');
    if (v == null) return 'right';
    if (v == 'left' || v == 'center' || v == 'right') return v;
    return 'right';
  }

  // Hide greeting preference
  static Future<void> setHideGreeting(bool value) async {
    await _ensurePrefs();
    await _prefs!.setBool('hide_greeting', value);
  }

  static bool getHideGreeting() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getBool('hide_greeting') ?? false;
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    try {
      debugPrint('[StorageService] Starting import process...');
      debugPrint('[StorageService] Import data keys: ${data.keys.toList()}');

      // Ensure storage is fully initialized
      await waitTodosReady();

      debugPrint('[StorageService] Clearing data...');
      await clearAllTodos();

      // Clear folders and templates if repositories are available
      if (_folderRepository != null) {
        final folders = await _folderRepository!.getAllFolders();
        for (final folder in folders) {
          if (!folder.isDefault) {
            // Don't delete default folders
            await _folderRepository!.deleteFolder(folder.id);
          }
        }
      }

      if (_templateRepository != null) {
        final templates = await _templateRepository!.getAllTemplates();
        for (final template in templates) {
          if (!template.isBuiltIn) {
            // Don't delete built-in templates
            await _templateRepository!.deleteTemplate(template.id);
          }
        }
      }

      // Import folders
      if (data['folders'] != null && _folderRepository != null) {
        final foldersData = data['folders'] as List;
        debugPrint(
          '[StorageService] Importing ${foldersData.length} folders...',
        );
        for (final folderJson in foldersData) {
          final folder = Folder.fromJson(folderJson);
          await _folderRepository!.createFolder(folder);
          debugPrint('[StorageService] Imported folder: ${folder.name}');
        }
      }

      // Import templates
      if (data['templates'] != null && _templateRepository != null) {
        final templatesData = data['templates'] as List;
        debugPrint(
          '[StorageService] Importing ${templatesData.length} templates...',
        );
        for (final templateJson in templatesData) {
          final template = FolderTemplate.fromJson(templateJson);
          // Only import custom templates or if user customized built-in ones
          if (!template.isBuiltIn || template.isCustomized) {
            await _templateRepository!.createTemplate(template);
            debugPrint('[StorageService] Imported template: ${template.name}');
          }
        }
      }

      // Import notes
      if (data['notes'] != null) {
        await waitNotesReady();
        final notesData = data['notes'] as List;
        debugPrint('[StorageService] Importing ${notesData.length} notes...');

        await clearAllNotes();

        for (final noteJson in notesData) {
          final note = Note.fromJson(noteJson);
          await saveNote(note);
          debugPrint('[StorageService] Imported note: ${note.title}');
        }
      }

      // Import todos
      if (data['todos'] != null) {
        final todosData = data['todos'] as List;
        debugPrint('[StorageService] Importing ${todosData.length} todos...');
        for (final todoJson in todosData) {
          final todo = Todo.fromJson(todoJson);
          await saveTodo(todo);
          debugPrint('[StorageService] Imported todo: ${todo.text}');
        }
      }

      // Import settings
      if (data['settings'] != null) {
        debugPrint('[StorageService] Importing settings...');
        final settings = data['settings'];
        await setThemeMode(settings['theme_mode'] ?? 'system');
        await setDefaultCategory(settings['default_category'] ?? 'personal');
        await setDefaultPriority(settings['default_priority'] ?? 'medium');
        await setNotificationsEnabled(
          settings['notifications_enabled'] ?? true,
        );
        await setAutoDeleteCompleted(
          settings['auto_delete_completed'] ?? false,
        );
        await setShowCompletedTasks(settings['show_completed_tasks'] ?? true);
      }

      debugPrint('[StorageService] Import completed successfully!');
    } catch (e, stackTrace) {
      debugPrint('[StorageService] Import failed: $e');
      debugPrint('[StorageService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<void> clearAllData() async {
    await waitTodosReady();
    await waitNotesReady();

    await clearAllTodos();
    await clearAllNotes();

    if (_folderRepository != null) {
      final folders = await _folderRepository!.getAllFolders();
      for (final folder in folders) {
        if (!folder.isDefault) {
          await _folderRepository!.deleteFolder(folder.id);
        }
      }
    }

    if (_templateRepository != null) {
      final templates = await _templateRepository!.getAllTemplates();
      for (final template in templates) {
        if (!template.isBuiltIn) {
          await _templateRepository!.deleteTemplate(template.id);
        }
      }
    }
  }

  // Cleanup and close
  static Future<void> dispose() async {
    await _todosLazyBox?.close();
  }
}
