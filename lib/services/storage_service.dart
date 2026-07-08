// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import '../models/folder.dart';
import '../models/folder_template.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/note_history.dart';
import '../models/holiday.dart';
import '../models/event.dart';
import '../repositories/isar_folder_repository.dart';
import '../repositories/isar_folder_template_repository.dart';
import '../utils/encryption_helper.dart';
import '../utils/isar_id.dart';

class StorageService {
  static Isar? _isar;
  static Isar get isar {
    final instance = _isar;
    if (instance == null) {
      throw StateError('StorageService.init() must complete before using Isar');
    }
    return instance;
  }

  static SharedPreferences? _prefs;
  static Completer<void>? _prefsCompleter; // separate fast prefs init
  // Exposed readiness flag so preference notifiers can avoid redundant async reloads.
  static bool get prefsReady => _prefs != null;
  static IsarFolderRepository? _folderRepository;
  static IsarFolderTemplateRepository? _templateRepository;
  // Toggle for console logging (timings, deferred open). Disable in tests for cleaner output.
  static bool enableLogging = true;

  /// When true, deferred opens (notes/todos/folders) will run synchronously
  /// inside `init()` instead of being scheduled in a microtask. This helps
  /// widget tests avoid background timers and pending futures. Tests should
  /// set `StorageService.performDeferredSynchronously = true` in setUpAll if
  /// they call `StorageService.init()` and expect no background timers.
  static bool performDeferredSynchronously = false;

  static bool _initialized = false; // core (prefs + isar init) ready
  static Completer<void>?
  _initCompleter; // completion for initial (settings only) init
  static Completer<void>? _todosCompleter; // completion for Isar init
  static Completer<void>? _eventsCompleter; // completion for Isar init
  static Completer<void>? _notesCompleter; // completion for Isar init
  static Completer<void>? _noteFoldersCompleter; // completion for Isar init
  static Completer<void>? _noteHistoryCompleter; // completion for Isar init

  // Initialize Isar and preferences
  static Future<void> init() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    final start = DateTime.now();
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([
      TodoSchema,
      EventSchema,
      NoteSchema,
      NoteFolderSchema,
      NoteHistoryEntrySchema,
      FolderSchema,
      FolderTemplateSchema,
      HolidaySchema,
    ], directory: dir.path);
    final afterIsar = DateTime.now();

    // SharedPreferences (fast)
    await _ensurePrefs();
    final afterPrefs = DateTime.now();

    // Schedule or run deferred initialization without blocking UI.
    FutureOr<void> runDeferred() async {
      _noteFoldersCompleter ??= Completer<void>();
      try {
        await _initializeDefaultVaultFolder();
        _noteFoldersCompleter?.complete();
      } catch (e, st) {
        _noteFoldersCompleter?.completeError(e, st);
      }

      _notesCompleter ??= Completer<void>();
      try {
        if (await isar.notes.count() > 0) {
          await _migrateWelcomeNote();
        }
        _notesCompleter?.complete();
      } catch (e, st) {
        _notesCompleter?.completeError(e, st);
      }

      _todosCompleter ??= Completer<void>();
      final todosStart = DateTime.now();
      try {
        _todosCompleter?.complete();
        final dur = DateTime.now().difference(todosStart).inMilliseconds;
        if (enableLogging) {
          debugPrint('[StorageService.deferred] todos ready in ${dur}ms');
        }
      } catch (e, st) {
        _todosCompleter?.completeError(e, st);
      }

      _eventsCompleter ??= Completer<void>();
      try {
        _eventsCompleter?.complete();
      } catch (e, st) {
        _eventsCompleter?.completeError(e, st);
      }

      _noteHistoryCompleter ??= Completer<void>();
      try {
        _noteHistoryCompleter?.complete();
      } catch (e, st) {
        _noteHistoryCompleter?.completeError(e, st);
      }

      final repoStart = DateTime.now();
      try {
        _folderRepository = IsarFolderRepository();
        await _folderRepository!.init();

        // Initialize template repository
        _templateRepository = IsarFolderTemplateRepository();
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
        '[StorageService.init] isar=${afterIsar.difference(start).inMilliseconds}ms prefs=${afterPrefs.difference(afterIsar).inMilliseconds}ms deferredScheduled=${afterRepo.difference(afterPrefs).inMilliseconds}ms totalCritical=${afterRepo.difference(start).inMilliseconds}ms',
      );
    }
    _initialized = true;
    _initCompleter!.complete();
  }

  static Future<void> ensureReady() => init();

  // Lightweight prefs-only init usable before full init (Isar) occurs.
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
    if (_isar != null) return;
    await ensureReady();
    _todosCompleter ??= Completer<void>();
    return _todosCompleter!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {},
    );
  }

  static Future<void> waitEventsReady() async {
    if (_isar != null) return;
    await ensureReady();
    _eventsCompleter ??= Completer<void>();
    return _eventsCompleter!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {},
    );
  }

  static Future<void> waitNotesReady() async {
    if (_isar != null) return;
    await ensureReady();
    _notesCompleter ??= Completer<void>();
    return _notesCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
  }

  // Getter for folder repository
  static IsarFolderRepository? get folderRepository => _folderRepository;

  /// Finds and replaces the welcome note if it hasn't been updated yet.
  /// Uses a SharedPreferences key to ensure the migration only runs once.
  static Future<void> _migrateWelcomeNote() async {
    const versionKey = 'welcome_note_version';
    const currentVersion = 2;
    final storedVersion = _prefs?.getInt(versionKey) ?? 0;
    if (storedVersion >= currentVersion) return;

    final target = await isar.notes
        .filter()
        .titleEqualTo('Welcome')
        .or()
        .titleEqualTo('Welcome to Trudido')
        .findFirst();

    if (target != null) {
      final updated = target.copyWith(
        title: 'Welcome to Trudido',
        content: '''# Welcome to Trudido

---

## Text Formatting

**Bold**, *italic*, <u>underline</u>, ~~strikethrough~~, and ==highlight==.

---

## Lists

- Capture ideas as bullet points
- Organise and reorder freely
- Nest items for structure

1. First step
2. Second step
3. Third step

---

## Checkboxes

- [ ] A task to complete
- [ ] Another pending item
- [x] Something already done

---

## Quote

> Block quotes stand out for important thoughts or citations.

---

## Code

Inline `code` works inside any sentence, or use a fenced block:

```
function greet(name) {
  return "Hello, " + name + "!";
}
```

---

## @Mentions

Type **@** anywhere to search and link a task, event, or note inline. The linked item becomes tappable — tap it to jump directly to the referenced item.

---

## Links

[Visit example.com](https://example.com)

---

## Tables & Media

Type **/** to open the insert menu:
- 📊 **Table** — interactive grid you can tap to edit, add or remove rows and columns
- 📸 **Photo** — from gallery or camera
- 🎥 **Video**
- 🎤 **Voice recording**
- 🔗 **Link**
- `</>` **Code block**
''',
      );
      await isar.writeTxn(() => isar.notes.put(updated));
    }

    await _prefs?.setInt(versionKey, currentVersion);
  }

  static Future<void> _initializeDefaultVaultFolder() async {
    await ensureReady();

    if (await isar.noteFolders.count() > 0) return;

    final vaultFolder = NoteFolder(
      name: 'Vault',
      description: 'Secure encrypted folder for private notes',
      isVault: true,
      hasPassword: false, // No password set initially
      useBiometric: true,
      sortOrder: 0,
      color: 0xFFFFC107,
    );
    await isar.writeTxn(() => isar.noteFolders.put(vaultFolder));

    if (enableLogging) {
      debugPrint('[StorageService] Created default Vault folder');
    }
  }

  // Todo operations
  static Future<void> saveTodo(Todo todo) async {
    await waitTodosReady();
    try {
      await isar.writeTxn(() => isar.todos.put(todo));
    } catch (e, st) {
      debugPrint('[StorageService] saveTodo failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> deleteTodo(String id) async {
    await waitTodosReady();
    try {
      await isar.writeTxn(() async {
        final todo = await isar.todos.get(fastHash(id));
        if (todo != null) {
          todo.isDeleted = true;
          todo.deletedAt = DateTime.now();
          await isar.todos.put(todo);
        }
      });
    } catch (e, st) {
      debugPrint('[StorageService] deleteTodo failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> permanentlyDeleteTodo(String id) async {
    await waitTodosReady();
    await isar.writeTxn(() => isar.todos.delete(fastHash(id)));
  }

  static Future<void> restoreTodo(String id) async {
    await waitTodosReady();
    await isar.writeTxn(() async {
      final todo = await isar.todos.get(fastHash(id));
      if (todo != null) {
        todo.isDeleted = false;
        await isar.todos.put(todo);
      }
    });
  }

  static Future<void> updateTodo(Todo todo) async {
    await waitTodosReady();
    try {
      await isar.writeTxn(() => isar.todos.put(todo));
    } catch (e, st) {
      debugPrint('[StorageService] updateTodo failed: $e\n$st');
      rethrow;
    }
  }

  static List<Todo> getAllTodos() {
    return const [];
  }

  static Future<List<Todo>> getAllTodosAsync() async {
    await waitTodosReady();
    return isar.todos.filter().isDeletedEqualTo(false).findAll();
  }

  static Future<List<Todo>> getDeletedTodos() async {
    await waitTodosReady();
    return isar.todos.filter().isDeletedEqualTo(true).findAll();
  }

  static Future<Todo?> getTodoAsync(String id) async {
    await waitTodosReady();
    return isar.todos.get(fastHash(id));
  }

  static Future<void> clearAllTodos() async {
    await waitTodosReady();
    await isar.writeTxn(() => isar.todos.clear());
  }

  static Future<void> saveTodosOrder(List<Todo> todos) async {
    // Clear todos and save in new order
    await waitTodosReady();
    await isar.writeTxn(() async {
      await isar.todos.clear();
      await isar.todos.putAll(todos);
    });
  }

  /// Persists all notes in the given order (clear + re-insert).
  static Future<void> saveNotesOrder(List<Note> notes) async {
    await waitNotesReady();
    await isar.writeTxn(() async {
      await isar.notes.clear();
      await isar.notes.putAll(notes);
    });
  }

  // Event operations
  static Future<void> saveEvent(Event event) async {
    await waitEventsReady();
    try {
      await isar.writeTxn(() => isar.events.put(event));
    } catch (e, st) {
      debugPrint('[StorageService] saveEvent failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> deleteEvent(String id) async {
    await waitEventsReady();
    try {
      await isar.writeTxn(() async {
        final event = await isar.events.get(fastHash(id));
        if (event != null) {
          event.isDeleted = true;
          event.deletedAt = DateTime.now();
          await isar.events.put(event);
        }
      });
    } catch (e, st) {
      debugPrint('[StorageService] deleteEvent failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> permanentlyDeleteEvent(String id) async {
    await waitEventsReady();
    await isar.writeTxn(() => isar.events.delete(fastHash(id)));
  }

  static Future<void> restoreEvent(String id) async {
    await waitEventsReady();
    await isar.writeTxn(() async {
      final event = await isar.events.get(fastHash(id));
      if (event != null) {
        event.isDeleted = false;
        await isar.events.put(event);
      }
    });
  }

  static Future<void> updateEvent(Event event) async {
    await waitEventsReady();
    try {
      await isar.writeTxn(() => isar.events.put(event));
    } catch (e, st) {
      debugPrint('[StorageService] updateEvent failed: $e\n$st');
      rethrow;
    }
  }

  static Future<List<Event>> getAllEventsAsync() async {
    await waitEventsReady();
    return isar.events.filter().isDeletedEqualTo(false).findAll();
  }

  static Future<List<Event>> getDeletedEvents() async {
    await waitEventsReady();
    return isar.events.filter().isDeletedEqualTo(true).findAll();
  }

  static Future<Event?> getEventAsync(String id) async {
    await waitEventsReady();
    return isar.events.get(fastHash(id));
  }

  static Future<void> clearAllEvents() async {
    await waitEventsReady();
    await isar.writeTxn(() => isar.events.clear());
  }

  static Future<void> saveEventsOrder(List<Event> events) async {
    await waitEventsReady();
    await isar.writeTxn(() async {
      await isar.events.clear();
      await isar.events.putAll(events);
    });
  }

  // Notes operations
  static Future<void> saveNote(Note note) async {
    await waitNotesReady();
    await isar.writeTxn(() => isar.notes.put(note));
  }

  static Future<void> deleteNote(String id) async {
    await waitNotesReady();
    await isar.writeTxn(() async {
      final note = await isar.notes.get(fastHash(id));
      if (note != null) {
        note.isDeleted = true;
        note.deletedAt = DateTime.now();
        await isar.notes.put(note);
      }
    });
  }

  static Future<void> permanentlyDeleteNote(String id) async {
    await waitNotesReady();
    await isar.writeTxn(() => isar.notes.delete(fastHash(id)));
  }

  /// Purges bin items older than [daysInBin] days from both notes and todos.
  /// Items without a [deletedAt] timestamp are skipped (safe migration).
  static Future<void> purgeExpiredBinItems(int daysInBin) async {
    if (daysInBin <= 0) return;
    final cutoff = DateTime.now().subtract(Duration(days: daysInBin));

    await waitNotesReady();
    await isar.writeTxn(() async {
      await isar.notes
          .filter()
          .isDeletedEqualTo(true)
          .deletedAtLessThan(cutoff)
          .deleteAll();
    });

    await waitTodosReady();
    await isar.writeTxn(() async {
      await isar.todos
          .filter()
          .isDeletedEqualTo(true)
          .deletedAtLessThan(cutoff)
          .deleteAll();
    });

    await waitEventsReady();
    await isar.writeTxn(() async {
      await isar.events
          .filter()
          .isDeletedEqualTo(true)
          .deletedAtLessThan(cutoff)
          .deleteAll();
    });
  }

  static Future<void> restoreNote(String id) async {
    await waitNotesReady();
    await isar.writeTxn(() async {
      final note = await isar.notes.get(fastHash(id));
      if (note != null) {
        note.isDeleted = false;
        await isar.notes.put(note);
      }
    });
  }

  static List<Note> getAllNotes() {
    if (_isar == null) return const [];
    return isar.notes.filter().isDeletedEqualTo(false).findAllSync();
  }

  static List<Note> getDeletedNotes() {
    if (_isar == null) return const [];
    return isar.notes.filter().isDeletedEqualTo(true).findAllSync();
  }

  static Note? getNote(String id) {
    if (_isar == null) return null;
    return isar.notes.getSync(fastHash(id));
  }

  static Future<void> clearAllNotes() async {
    await waitNotesReady();
    await isar.writeTxn(() => isar.notes.clear());
  }

  // Note folders operations
  static Future<void> saveNoteFolder(NoteFolder folder) async {
    await waitNoteFoldersReady();
    await isar.writeTxn(() => isar.noteFolders.put(folder));
  }

  static Future<void> deleteNoteFolder(String id) async {
    await waitNoteFoldersReady();
    await isar.writeTxn(() => isar.noteFolders.delete(fastHash(id)));
  }

  static List<NoteFolder> getAllNoteFolders() {
    if (_isar == null) return const [];
    return isar.noteFolders.where().findAllSync();
  }

  static NoteFolder? getNoteFolder(String id) {
    if (_isar == null) return null;
    return isar.noteFolders.getSync(fastHash(id));
  }

  static Future<void> waitNoteFoldersReady() async {
    if (_isar != null) return;
    await ensureReady();
    _noteFoldersCompleter ??= Completer<void>();
    return _noteFoldersCompleter!.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Note folders storage failed to open in time');
      },
    );
  }

  static Future<void> clearAllNoteFolders() async {
    await waitNoteFoldersReady();
    await isar.writeTxn(() => isar.noteFolders.clear());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Note History operations (for undo/redo and edit history)
  // ─────────────────────────────────────────────────────────────────────────

  /// Wait for note history box to be ready.
  static Future<void> waitNoteHistoryReady() async {
    if (_isar != null) return;
    await ensureReady();
    _noteHistoryCompleter ??= Completer<void>();
    return _noteHistoryCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
  }

  /// Save a note history entry.
  static Future<void> saveNoteHistoryEntry(NoteHistoryEntry entry) async {
    await waitNoteHistoryReady();
    await isar.writeTxn(() => isar.noteHistoryEntrys.put(entry));
  }

  /// Get all note history entries for a specific note, sorted newest first.
  static Future<List<NoteHistoryEntry>> getNoteHistoryForNote(
    String noteId,
  ) async {
    await waitNoteHistoryReady();
    return isar.noteHistoryEntrys
        .filter()
        .noteIdEqualTo(noteId)
        .sortByTimestampDesc()
        .findAll();
  }

  /// Get all note history entries, sorted newest first.
  static Future<List<NoteHistoryEntry>> getAllNoteHistory() async {
    await waitNoteHistoryReady();
    return isar.noteHistoryEntrys.where().sortByTimestampDesc().findAll();
  }

  /// Delete a single note history entry by ID.
  static Future<void> deleteNoteHistoryEntry(String id) async {
    await waitNoteHistoryReady();
    await isar.writeTxn(() => isar.noteHistoryEntrys.delete(fastHash(id)));
  }

  /// Delete all note history entries for a specific note.
  static Future<void> deleteNoteHistoryForNote(String noteId) async {
    await waitNoteHistoryReady();
    await isar.writeTxn(() {
      return isar.noteHistoryEntrys.filter().noteIdEqualTo(noteId).deleteAll();
    });
  }

  /// Clear all note history entries.
  static Future<void> clearAllNoteHistory() async {
    await waitNoteHistoryReady();
    await isar.writeTxn(() => isar.noteHistoryEntrys.clear());
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

  static Future<void> setUserAvatarPath(String path) async {
    await _ensurePrefs();
    await _prefs!.setString('user_avatar_path', path);
  }

  static String? getUserAvatarPath() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getString('user_avatar_path');
  }

  static Future<void> setAvatarBackgroundColor(int color) async {
    await _ensurePrefs();
    await _prefs!.setInt('avatar_bg_color', color);
  }

  static int? getAvatarBackgroundColor() {
    if (_prefs == null) kickOffPrefsInit();
    final value = _prefs?.getInt('avatar_bg_color');
    return value != null && value != 0 ? value : null;
  }

  static Future<void> setAvatarTextColor(int color) async {
    await _ensurePrefs();
    await _prefs!.setInt('avatar_text_color', color);
  }

  static int? getAvatarTextColor() {
    if (_prefs == null) kickOffPrefsInit();
    final value = _prefs?.getInt('avatar_text_color');
    return value != null && value != 0 ? value : null;
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

  // Overview drawer modules (list of module type strings)
  static Future<void> setOverviewDrawerModules(List<String> modules) async {
    await _ensurePrefs();
    await _prefs!.setStringList('overview_drawer_modules', modules);
  }

  static List<String> getOverviewDrawerModules() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getStringList('overview_drawer_modules') ??
        ['calendar', 'none', 'none'];
  }

  // Per-tab drawer module (single module slot for Tasks/Notes tabs)
  static Future<void> setTabDrawerModule(int tab, String moduleType) async {
    await _ensurePrefs();
    await _prefs!.setString('tab_drawer_module_$tab', moduleType);
  }

  static String getTabDrawerModule(int tab) {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getString('tab_drawer_module_$tab') ?? 'none';
  }

  // Overview section order
  static Future<void> setOverviewSectionOrder(List<String> order) async {
    await _ensurePrefs();
    await _prefs!.setStringList('overview_section_order', order);
  }

  static List<String> getOverviewSectionOrder() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getStringList('overview_section_order') ??
        [
          'clock',
          'greeting',
          'folder_shortcuts',
          'progress',
          'todos',
          'events',
          'latest_notes',
        ];
  }

  // Overview hidden sections
  static Future<void> setOverviewHiddenSections(Set<String> hidden) async {
    await _ensurePrefs();
    await _prefs!.setStringList('overview_hidden_sections', hidden.toList());
  }

  static Set<String> getOverviewHiddenSections() {
    if (_prefs == null) kickOffPrefsInit();
    return (_prefs?.getStringList('overview_hidden_sections') ?? []).toSet();
  }

  // Recently visited settings screens (keys, most recent first, max 3)
  static Future<void> setRecentSettings(List<String> keys) async {
    await _ensurePrefs();
    await _prefs!.setStringList('recent_settings', keys);
  }

  static List<String> getRecentSettings() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getStringList('recent_settings') ?? [];
  }

  // Recently used note tags (most recent first, max 20)
  static Future<void> setRecentNoteTags(List<String> tags) async {
    await _ensurePrefs();
    await _prefs!.setStringList('recent_note_tags', tags);
  }

  static List<String> getRecentNoteTags() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getStringList('recent_note_tags') ?? [];
  }

  // Notes drawer tag scope preference: 'all' or 'folder'
  static Future<void> setNotesDrawerTagScope(String scope) async {
    await _ensurePrefs();
    await _prefs!.setString('notes_drawer_tag_scope', scope);
  }

  static String getNotesDrawerTagScope() {
    if (_prefs == null) kickOffPrefsInit();
    final value = _prefs?.getString('notes_drawer_tag_scope');
    if (value == 'folder') {
      return 'folder';
    }
    return 'all';
  }

  // Pinned overview note ID
  static Future<void> setPinnedOverviewNoteId(String? noteId) async {
    await _ensurePrefs();
    if (noteId == null) {
      await _prefs!.remove('pinned_overview_note_id');
    } else {
      await _prefs!.setString('pinned_overview_note_id', noteId);
    }
  }

  static String? getPinnedOverviewNoteId() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getString('pinned_overview_note_id');
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

  // Auto-backup password (optional - for encrypting automatic backups)
  static Future<void> setAutoBackupPassword(String? password) async {
    await _ensurePrefs();
    if (password == null || password.isEmpty) {
      await _prefs!.remove('auto_backup_password');
    } else {
      await _prefs!.setString('auto_backup_password', password);
    }
  }

  static String? getAutoBackupPassword() {
    if (_prefs == null) kickOffPrefsInit();
    return _prefs?.getString('auto_backup_password');
  }

  /// Export data for auto-backup (called from Android via MethodChannel)
  /// Returns JSON string, optionally encrypted if auto-backup password is set
  static Future<String> exportDataForAutoBackup() async {
    debugPrint('[StorageService] Exporting data for auto-backup...');
    final data = await exportData();
    var jsonString = jsonEncode(data);

    // Encrypt if auto-backup password is set
    final password = getAutoBackupPassword();
    if (password != null && password.isNotEmpty) {
      debugPrint('[StorageService] Encrypting auto-backup with password...');
      jsonString = EncryptionHelper.encryptBackupWithPassword(
        jsonString,
        password,
      );
    }

    debugPrint(
      '[StorageService] Auto-backup export complete, length: ${jsonString.length}',
    );
    return jsonString;
  }

  // Backup and restore functionality
  static Future<Map<String, dynamic>> exportData() async {
    try {
      debugPrint('[StorageService] Starting export process...');

      final todos = await getAllTodosAsync().then(
        (l) => l.map((todo) => todo.toJson()).toList(),
      );

      // Export notes - decrypt vault notes before export
      await waitNotesReady();
      await waitNoteFoldersReady();
      final rawNotes = getAllNotes();
      final noteFolders = getAllNoteFolders();

      // Create a set of vault folder IDs for quick lookup
      final vaultFolderIds = noteFolders
          .where((f) => f.isVault)
          .map((f) => f.id)
          .toSet();

      // Decrypt notes that are in vault folders before export
      final decryptedNotes = <Map<String, dynamic>>[];
      for (final note in rawNotes) {
        if (note.folderId != null && vaultFolderIds.contains(note.folderId)) {
          try {
            // Decrypt vault note before export
            final decryptedTitle = await EncryptionHelper.decryptText(
              note.title,
            );
            final decryptedContent = await EncryptionHelper.decryptText(
              note.content,
            );
            final decryptedNote = note.copyWith(
              title: decryptedTitle,
              content: decryptedContent,
            );
            decryptedNotes.add(decryptedNote.toJson());
            debugPrint(
              '[StorageService] Decrypted vault note for export: ${decryptedTitle.substring(0, decryptedTitle.length.clamp(0, 20))}...',
            );
          } catch (e) {
            // If decryption fails, export as-is (might be already decrypted or corrupted)
            debugPrint(
              '[StorageService] Failed to decrypt note ${note.id}, exporting as-is: $e',
            );
            decryptedNotes.add(note.toJson());
          }
        } else {
          // Non-vault note, export as-is
          decryptedNotes.add(note.toJson());
        }
      }

      // Export note folders (including vault folders)
      final noteFoldersJson = noteFolders
          .map((folder) => folder.toJson())
          .toList();

      // Export task folders
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

      // Export events
      final events = await getAllEventsAsync().then(
        (l) => l.map((event) => event.toJson()).toList(),
      );

      debugPrint(
        '[StorageService] Exporting ${todos.length} todos, ${events.length} events, ${decryptedNotes.length} notes, '
        '${noteFoldersJson.length} note folders, ${folders.length} task folders, '
        'and ${templates.length} templates',
      );

      final exportMap = {
        'todos': todos,
        'events': events,
        'notes': decryptedNotes,
        'noteFolders': noteFoldersJson,
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
        'version': '1.4.0', // Version bump for events support
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
    if (position != 'left' && position != 'center' && position != 'right') {
      return;
    }
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
      await waitNotesReady();
      await waitNoteFoldersReady();

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

      // Clear and import note folders FIRST (before notes, so notes can reference them)
      // This includes vault folders
      final existingNoteFolders = getAllNoteFolders();
      for (final folder in existingNoteFolders) {
        await deleteNoteFolder(folder.id);
      }

      // Build a set of vault folder IDs for re-encryption
      final vaultFolderIds = <String>{};

      if (data['noteFolders'] != null) {
        final noteFoldersData = data['noteFolders'] as List;
        debugPrint(
          '[StorageService] Importing ${noteFoldersData.length} note folders...',
        );
        for (final folderJson in noteFoldersData) {
          final folder = NoteFolder.fromJson(
            folderJson as Map<String, dynamic>,
          );
          await saveNoteFolder(folder);
          if (folder.isVault) {
            vaultFolderIds.add(folder.id);
          }
          debugPrint(
            '[StorageService] Imported note folder: ${folder.name} (isVault: ${folder.isVault})',
          );
        }
      }

      // Import task folders
      if (data['folders'] != null && _folderRepository != null) {
        final foldersData = data['folders'] as List;
        debugPrint(
          '[StorageService] Importing ${foldersData.length} task folders...',
        );
        for (final folderJson in foldersData) {
          final folder = Folder.fromJson(folderJson);
          await _folderRepository!.createFolder(folder);
          debugPrint('[StorageService] Imported task folder: ${folder.name}');
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

      // Import notes - re-encrypt vault notes on import
      if (data['notes'] != null) {
        final notesData = data['notes'] as List;
        debugPrint('[StorageService] Importing ${notesData.length} notes...');

        await clearAllNotes();

        for (final noteJson in notesData) {
          var note = Note.fromJson(noteJson);

          // Re-encrypt notes that belong to vault folders
          if (note.folderId != null && vaultFolderIds.contains(note.folderId)) {
            try {
              final encryptedTitle = await EncryptionHelper.encryptText(
                note.title,
              );
              final encryptedContent = await EncryptionHelper.encryptText(
                note.content,
              );
              note = note.copyWith(
                title: encryptedTitle,
                content: encryptedContent,
              );
              debugPrint('[StorageService] Re-encrypted vault note for import');
            } catch (e) {
              debugPrint(
                '[StorageService] Failed to encrypt note ${note.id}: $e',
              );
              // Continue with unencrypted note - better than losing data
            }
          }

          await saveNote(note);
          debugPrint(
            '[StorageService] Imported note: ${note.title.substring(0, note.title.length.clamp(0, 30))}...',
          );
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

      // Import events
      if (data['events'] != null) {
        final eventsData = data['events'] as List;
        debugPrint('[StorageService] Importing ${eventsData.length} events...');
        await clearAllEvents();
        for (final eventJson in eventsData) {
          final event = Event.fromJson(eventJson as Map<String, dynamic>);
          await saveEvent(event);
          debugPrint('[StorageService] Imported event: ${event.text}');
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
    await waitEventsReady();
    await waitNotesReady();

    await clearAllTodos();
    await clearAllEvents();
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
    await _isar?.close();
    _isar = null;
    _initialized = false;
  }

  // ============================================================================
  // Custom Themes
  // ============================================================================

  static const String _customThemesKey = 'custom_themes';
  static const String _activeCustomThemeKey = 'active_custom_theme_id';

  /// Save a custom theme (creates or updates)
  static Future<void> saveCustomTheme(String id, String jsonString) async {
    await _ensurePrefs();
    final themes = _getCustomThemesMap();
    themes[id] = jsonString;
    await _prefs!.setString(_customThemesKey, jsonEncode(themes));
  }

  /// Delete a custom theme by id
  static Future<void> deleteCustomTheme(String id) async {
    await _ensurePrefs();
    final themes = _getCustomThemesMap();
    themes.remove(id);
    await _prefs!.setString(_customThemesKey, jsonEncode(themes));
    // Clear active theme if it was the deleted one
    if (getActiveCustomThemeId() == id) {
      await clearActiveCustomTheme();
    }
  }

  /// Get all saved custom themes as map of id -> JSON string
  static Map<String, String> _getCustomThemesMap() {
    if (_prefs == null) kickOffPrefsInit();
    final raw = _prefs?.getString(_customThemesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  /// Get all saved custom theme JSON strings
  static List<String> getAllCustomThemes() {
    return _getCustomThemesMap().values.toList();
  }

  /// Get a specific custom theme JSON by id
  static String? getCustomTheme(String id) {
    return _getCustomThemesMap()[id];
  }

  /// Set the active custom theme id (null or empty to deactivate)
  static Future<void> setActiveCustomThemeId(String id) async {
    await _ensurePrefs();
    await _prefs!.setString(_activeCustomThemeKey, id);
  }

  /// Clear active custom theme (use normal theme system)
  static Future<void> clearActiveCustomTheme() async {
    await _ensurePrefs();
    await _prefs!.remove(_activeCustomThemeKey);
  }

  /// Get the currently active custom theme id, or null
  static String? getActiveCustomThemeId() {
    if (_prefs == null) kickOffPrefsInit();
    final id = _prefs?.getString(_activeCustomThemeKey);
    return (id != null && id.isNotEmpty) ? id : null;
  }

  // ============================================================================
  // Spatial Canvas Positions
  // ============================================================================

  static String _freeformKey(String folderKey) =>
      'note_freeform_positions_$folderKey';

  /// Save Spatial Canvas positions for a folder.
  /// [folderKey] is the folder ID or 'ALL' for the all-notes view.
  static Future<void> saveFreeformPositions(
    String folderKey,
    Map<String, List<double>> positions,
  ) async {
    await _ensurePrefs();
    await _prefs!.setString(_freeformKey(folderKey), jsonEncode(positions));
  }

  /// Load Spatial Canvas positions for a folder.
  /// Returns a map of noteId -> [dx, dy].
  static Map<String, List<double>> loadFreeformPositions(String folderKey) {
    if (_prefs == null) kickOffPrefsInit();
    final raw = _prefs?.getString(_freeformKey(folderKey));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) {
        final list = (v as List).cast<num>();
        return MapEntry(k, [list[0].toDouble(), list[1].toDouble()]);
      });
    } catch (_) {
      return {};
    }
  }
}
