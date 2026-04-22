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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import '../models/folder.dart';
import '../models/folder_template.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/note_history.dart';
import '../models/holiday.dart';
import '../models/event.dart';
import '../repositories/hive_folder_repository.dart';
import '../repositories/hive_folder_template_repository.dart';
import '../utils/encryption_helper.dart';

class StorageService {
  static const String _todosBoxName = 'todos';
  static const String _eventsBoxName = 'events';
  static const String _notesBoxName = 'notes';
  static const String _noteFoldersBoxName = 'note_folders';
  static const String _noteHistoryBoxName = 'note_history';

  // Deferred / lazy boxes
  static LazyBox<Todo>? _todosLazyBox; // large dataset
  static LazyBox<Event>? _eventsLazyBox; // events storage
  static Box<Note>? _notesBox; // notes storage
  static Box<NoteFolder>? _noteFoldersBox; // note folders storage
  static Box<NoteHistoryEntry>? _noteHistoryBox; // note edit history storage
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
  static Completer<void>?
  _eventsCompleter; // completion for events lazy box open
  static Completer<void>? _notesCompleter; // completion for notes box open
  static Completer<void>?
  _noteFoldersCompleter; // completion for note folders box open
  static Completer<void>?
  _noteHistoryCompleter; // completion for note history box open

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
    // Register holiday adapter
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(HolidayAdapter());
    }
    // Register note history adapter
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(NoteHistoryEntryAdapter());
    }
    // Register event adapter
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(EventAdapter());
    }
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
        if (_notesBox!.isNotEmpty) {
          await _migrateWelcomeNote();
        }
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

      // Events lazy box (potentially large, like todos)
      _eventsCompleter ??= Completer<void>();
      try {
        _eventsLazyBox = await Hive.openLazyBox<Event>(_eventsBoxName);
        _eventsCompleter?.complete();
        if (enableLogging) {
          debugPrint('[StorageService] Events lazy box opened successfully');
        }
      } catch (e, st) {
        _eventsCompleter?.completeError(e, st);
      }

      // Note history box (for undo/redo and edit history)
      _noteHistoryCompleter ??= Completer<void>();
      try {
        _noteHistoryBox = await Hive.openBox<NoteHistoryEntry>(
          _noteHistoryBoxName,
        );
        _noteHistoryCompleter?.complete();
        if (enableLogging) {
          debugPrint('[StorageService] Note history box opened successfully');
        }
      } catch (e) {
        if (enableLogging) {
          debugPrint(
            '[StorageService] Failed to initialize note history box: $e',
          );
        }
        // Attempt recovery by deleting and recreating the box
        try {
          await Hive.deleteBoxFromDisk(_noteHistoryBoxName);
          _noteHistoryBox = await Hive.openBox<NoteHistoryEntry>(
            _noteHistoryBoxName,
          );
          _noteHistoryCompleter?.complete();
          if (enableLogging) {
            debugPrint(
              '[StorageService] Successfully recovered note history box',
            );
          }
        } catch (recoveryError) {
          _noteHistoryCompleter?.completeError(recoveryError);
          if (enableLogging) {
            debugPrint(
              '[StorageService] Failed to recover note history box: $recoveryError',
            );
          }
        }
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

  static Future<void> waitEventsReady() async {
    if (_eventsLazyBox != null) return;
    await ensureReady();
    _eventsCompleter ??= Completer<void>();
    return _eventsCompleter!.future.timeout(
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

  /// Finds and replaces the welcome note if it hasn't been updated yet.
  /// Uses a SharedPreferences key to ensure the migration only runs once.
  static Future<void> _migrateWelcomeNote() async {
    const versionKey = 'welcome_note_version';
    const currentVersion = 2;
    final storedVersion = _prefs?.getInt(versionKey) ?? 0;
    if (storedVersion >= currentVersion) return;

    // Find the welcome note by its old or current title
    final box = _notesBox!;
    Note? target;
    for (final note in box.values) {
      if (note.title == 'Welcome' || note.title == 'Welcome to Trudido') {
        target = note;
        break;
      }
    }

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
      await box.put(target.id, updated);
    }

    await _prefs?.setInt(versionKey, currentVersion);
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
      _todosLazyBox ??= await Hive.openLazyBox<Todo>(_todosBoxName);
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
      _todosLazyBox ??= await Hive.openLazyBox<Todo>(_todosBoxName);
      if (_todosLazyBox != null) {
        final todo = await _todosLazyBox!.get(id);
        if (todo != null) {
          todo.isDeleted = true;
          todo.deletedAt = DateTime.now();
          await _todosLazyBox!.put(id, todo);
        }
        return;
      }
      throw Exception('Todos lazy box is not available');
    } catch (e, st) {
      debugPrint('[StorageService] deleteTodo failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> permanentlyDeleteTodo(String id) async {
    await waitTodosReady();
    if (_todosLazyBox != null) {
      await _todosLazyBox!.delete(id);
    }
  }

  static Future<void> restoreTodo(String id) async {
    await waitTodosReady();
    if (_todosLazyBox != null) {
      final todo = await _todosLazyBox!.get(id);
      if (todo != null) {
        todo.isDeleted = false;
        await _todosLazyBox!.put(id, todo);
      }
    }
  }

  static Future<void> updateTodo(Todo todo) async {
    await waitTodosReady();
    try {
      _todosLazyBox ??= await Hive.openLazyBox<Todo>(_todosBoxName);
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
        if (t != null && !t.isDeleted) list.add(t);
      }
      return list;
    }
    return const [];
  }

  static Future<List<Todo>> getDeletedTodos() async {
    await waitTodosReady();
    if (_todosLazyBox != null) {
      final keys = _todosLazyBox!.keys.cast<dynamic>().toList();
      final List<Todo> list = [];
      for (final k in keys) {
        final t = await _todosLazyBox!.get(k);
        if (t != null && t.isDeleted) list.add(t);
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

  /// Persists all notes in the given order (clear + re-insert).
  static Future<void> saveNotesOrder(List<Note> notes) async {
    await waitNotesReady();
    if (_notesBox != null) {
      await _notesBox!.clear();
      for (final n in notes) {
        await _notesBox!.put(n.id, n);
      }
    }
  }

  // Event operations
  static Future<void> saveEvent(Event event) async {
    await waitEventsReady();
    try {
      _eventsLazyBox ??= await Hive.openLazyBox<Event>(_eventsBoxName);
      if (_eventsLazyBox != null) {
        await _eventsLazyBox!.put(event.id, event);
        return;
      }
      throw Exception('Events lazy box is not available');
    } catch (e, st) {
      debugPrint('[StorageService] saveEvent failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> deleteEvent(String id) async {
    await waitEventsReady();
    try {
      _eventsLazyBox ??= await Hive.openLazyBox<Event>(_eventsBoxName);
      if (_eventsLazyBox != null) {
        final event = await _eventsLazyBox!.get(id);
        if (event != null) {
          event.isDeleted = true;
          event.deletedAt = DateTime.now();
          await _eventsLazyBox!.put(id, event);
        }
        return;
      }
      throw Exception('Events lazy box is not available');
    } catch (e, st) {
      debugPrint('[StorageService] deleteEvent failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> permanentlyDeleteEvent(String id) async {
    await waitEventsReady();
    if (_eventsLazyBox != null) {
      await _eventsLazyBox!.delete(id);
    }
  }

  static Future<void> restoreEvent(String id) async {
    await waitEventsReady();
    if (_eventsLazyBox != null) {
      final event = await _eventsLazyBox!.get(id);
      if (event != null) {
        event.isDeleted = false;
        await _eventsLazyBox!.put(id, event);
      }
    }
  }

  static Future<void> updateEvent(Event event) async {
    await waitEventsReady();
    try {
      _eventsLazyBox ??= await Hive.openLazyBox<Event>(_eventsBoxName);
      if (_eventsLazyBox != null) {
        await _eventsLazyBox!.put(event.id, event);
        return;
      }
      throw Exception('Events lazy box is not available');
    } catch (e, st) {
      debugPrint('[StorageService] updateEvent failed: $e\n$st');
      rethrow;
    }
  }

  static Future<List<Event>> getAllEventsAsync() async {
    await waitEventsReady();
    if (_eventsLazyBox != null) {
      final keys = _eventsLazyBox!.keys.cast<dynamic>().toList();
      final List<Event> list = [];
      for (final k in keys) {
        final e = await _eventsLazyBox!.get(k);
        if (e != null && !e.isDeleted) list.add(e);
      }
      return list;
    }
    return const [];
  }

  static Future<List<Event>> getDeletedEvents() async {
    await waitEventsReady();
    if (_eventsLazyBox != null) {
      final keys = _eventsLazyBox!.keys.cast<dynamic>().toList();
      final List<Event> list = [];
      for (final k in keys) {
        final e = await _eventsLazyBox!.get(k);
        if (e != null && e.isDeleted) list.add(e);
      }
      return list;
    }
    return const [];
  }

  static Future<Event?> getEventAsync(String id) async {
    await waitEventsReady();
    if (_eventsLazyBox != null) return _eventsLazyBox!.get(id);
    return null;
  }

  static Future<void> clearAllEvents() async {
    await waitEventsReady();
    if (_eventsLazyBox != null) {
      await _eventsLazyBox!.clear();
      return;
    }
  }

  static Future<void> saveEventsOrder(List<Event> events) async {
    await waitEventsReady();
    if (_eventsLazyBox != null) {
      await _eventsLazyBox!.clear();
      for (final e in events) {
        await _eventsLazyBox!.put(e.id, e);
      }
      return;
    }
  }

  // Notes operations
  static Future<void> saveNote(Note note) async {
    if (_notesBox == null) {
      throw Exception('Notes storage not initialized. Cannot save note.');
    }
    await _notesBox!.put(note.id, note);
  }

  static Future<void> deleteNote(String id) async {
    if (_notesBox == null) return;
    final note = _notesBox!.get(id);
    if (note != null) {
      note.isDeleted = true;
      note.deletedAt = DateTime.now();
      await _notesBox!.put(id, note);
    }
  }

  static Future<void> permanentlyDeleteNote(String id) async {
    if (_notesBox == null) return;
    await _notesBox!.delete(id);
  }

  /// Purges bin items older than [daysInBin] days from both notes and todos.
  /// Items without a [deletedAt] timestamp are skipped (safe migration).
  static Future<void> purgeExpiredBinItems(int daysInBin) async {
    if (daysInBin <= 0) return;
    final cutoff = DateTime.now().subtract(Duration(days: daysInBin));

    // Purge expired notes
    if (_notesBox != null) {
      final expiredNoteIds = _notesBox!.values
          .where(
            (n) =>
                n.isDeleted &&
                n.deletedAt != null &&
                n.deletedAt!.isBefore(cutoff),
          )
          .map((n) => n.id)
          .toList();
      for (final id in expiredNoteIds) {
        await _notesBox!.delete(id);
      }
    }

    // Purge expired todos
    await waitTodosReady();
    if (_todosLazyBox != null) {
      final keys = _todosLazyBox!.keys.cast<dynamic>().toList();
      for (final k in keys) {
        final todo = await _todosLazyBox!.get(k);
        if (todo != null &&
            todo.isDeleted &&
            todo.deletedAt != null &&
            todo.deletedAt!.isBefore(cutoff)) {
          await _todosLazyBox!.delete(k);
        }
      }
    }

    // Purge expired events
    await waitEventsReady();
    if (_eventsLazyBox != null) {
      final keys = _eventsLazyBox!.keys.cast<dynamic>().toList();
      for (final k in keys) {
        final event = await _eventsLazyBox!.get(k);
        if (event != null &&
            event.isDeleted &&
            event.deletedAt != null &&
            event.deletedAt!.isBefore(cutoff)) {
          await _eventsLazyBox!.delete(k);
        }
      }
    }
  }

  static Future<void> restoreNote(String id) async {
    if (_notesBox == null) return;
    final note = _notesBox!.get(id);
    if (note != null) {
      note.isDeleted = false;
      await _notesBox!.put(id, note);
    }
  }

  static List<Note> getAllNotes() {
    if (_notesBox == null) return const [];
    return _notesBox!.values.where((n) => !n.isDeleted).toList();
  }

  static List<Note> getDeletedNotes() {
    if (_notesBox == null) return const [];
    return _notesBox!.values.where((n) => n.isDeleted).toList();
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

  // ─────────────────────────────────────────────────────────────────────────
  // Note History operations (for undo/redo and edit history)
  // ─────────────────────────────────────────────────────────────────────────

  /// Wait for note history box to be ready.
  static Future<void> waitNoteHistoryReady() async {
    if (_noteHistoryBox != null) return;
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
    if (_noteHistoryBox == null) return;
    await _noteHistoryBox!.put(entry.id, entry);
  }

  /// Get all note history entries for a specific note, sorted newest first.
  static Future<List<NoteHistoryEntry>> getNoteHistoryForNote(
    String noteId,
  ) async {
    await waitNoteHistoryReady();
    if (_noteHistoryBox == null) return const [];
    final entries = _noteHistoryBox!.values
        .where((e) => e.noteId == noteId)
        .toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Get all note history entries, sorted newest first.
  static Future<List<NoteHistoryEntry>> getAllNoteHistory() async {
    await waitNoteHistoryReady();
    if (_noteHistoryBox == null) return const [];
    final entries = _noteHistoryBox!.values.toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Delete a single note history entry by ID.
  static Future<void> deleteNoteHistoryEntry(String id) async {
    await waitNoteHistoryReady();
    if (_noteHistoryBox == null) return;
    await _noteHistoryBox!.delete(id);
  }

  /// Delete all note history entries for a specific note.
  static Future<void> deleteNoteHistoryForNote(String noteId) async {
    await waitNoteHistoryReady();
    if (_noteHistoryBox == null) return;
    final keysToDelete = _noteHistoryBox!.keys.where((key) {
      final entry = _noteHistoryBox!.get(key);
      return entry != null && entry.noteId == noteId;
    }).toList();
    for (final key in keysToDelete) {
      await _noteHistoryBox!.delete(key);
    }
  }

  /// Clear all note history entries.
  static Future<void> clearAllNoteHistory() async {
    await waitNoteHistoryReady();
    if (_noteHistoryBox == null) return;
    await _noteHistoryBox!.clear();
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
    await _todosLazyBox?.close();
    await _eventsLazyBox?.close();
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
