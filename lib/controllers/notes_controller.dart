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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../providers/notes_providers.dart';
import '../repositories/note_folder_repository.dart';
import '../repositories/notes_repository.dart';
import '../services/storage_service.dart';
import '../utils/date_search_parser.dart';
import '../utils/state_notifiers.dart';

/// Provider for selected folder filter (null = all notes)
final selectedNoteFolderProvider = stateProvider<String?>(null);

/// Provider for tracking the last accessed vault folder ID
final lastAccessedVaultProvider = stateProvider<String?>(null);

/// Controller for handling notes business logic
class NotesController extends Notifier<AsyncValue<void>> {
  NotesNotifier get _notesNotifier => ref.read(notesProvider.notifier);

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Creates a new note
  Future<Note?> createNote({
    required String title,
    required String content,
    String? folderId,
    String? todoTxtContent,
    double? lineHeightMultiplier,
    double? paragraphSpacing,
    List<String>? tags,
  }) async {
    if (title.trim().isEmpty) {
      state = const AsyncValue.error('Title cannot be empty', StackTrace.empty);
      return null;
    }

    try {
      state = const AsyncValue.loading();
      final note = await _notesNotifier.createNote(
        title: title.trim(),
        content: content,
        folderId: folderId,
        todoTxtContent: todoTxtContent,
        lineHeightMultiplier: lineHeightMultiplier,
        paragraphSpacing: paragraphSpacing,
        tags: tags,
      );
      state = const AsyncValue.data(null);
      return note;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Updates an existing note
  Future<Note?> updateNote({
    required String id,
    String? title,
    String? content,
    String? todoTxtContent,
    double? lineHeightMultiplier,
    double? paragraphSpacing,
    bool? lastReadMode,
    List<String>? tags,
  }) async {
    if (title != null && title.trim().isEmpty) {
      state = const AsyncValue.error('Title cannot be empty', StackTrace.empty);
      return null;
    }

    try {
      state = const AsyncValue.loading();
      final note = _notesNotifier.updateNote(
        id: id,
        title: title?.trim(),
        content: content,
        todoTxtContent: todoTxtContent,
        lineHeightMultiplier: lineHeightMultiplier,
        paragraphSpacing: paragraphSpacing,
        lastReadMode: lastReadMode,
        tags: tags,
      );
      state = const AsyncValue.data(null);
      return note;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Updates a note's folder assignment
  Future<bool> updateNoteFolder(String noteId, String? folderId) async {
    try {
      state = const AsyncValue.loading();
      final note = await _notesNotifier.updateNoteFolder(noteId, folderId);
      state = const AsyncValue.data(null);
      return note != null;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Deletes a note
  Future<bool> deleteNote(String id) async {
    try {
      state = const AsyncValue.loading();
      final success = _notesNotifier.deleteNote(id);
      state = const AsyncValue.data(null);
      return success;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Bulk deletes multiple notes by ID
  Future<void> bulkDelete(Iterable<String> ids) async {
    try {
      state = const AsyncValue.loading();
      await _notesNotifier.bulkDelete(ids);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Sets the pinned status on multiple notes
  Future<void> bulkSetPin(Iterable<String> ids, bool pinned) async {
    try {
      state = const AsyncValue.loading();
      await _notesNotifier.bulkSetPin(ids, pinned);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Sets the same card color on multiple notes
  Future<void> bulkSetColor(Iterable<String> ids, int? colorValue) async {
    try {
      state = const AsyncValue.loading();
      await _notesNotifier.bulkSetColor(ids, colorValue);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Toggles the pinned status of a note
  Future<Note?> togglePin(String id) async {
    try {
      state = const AsyncValue.loading();
      final note = _notesNotifier.togglePin(id);
      state = const AsyncValue.data(null);
      return note;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Persists a reordered view list produced by drag-and-drop.
  ///
  /// [reorderedView] is the filtered/visible list in its new order.
  /// Notes not present in the view (other folders, vault, etc.) are
  /// appended so no data is lost.
  Future<void> commitReorder(List<Note> reorderedView) async {
    final allNotes = ref.read(notesProvider).value ?? [];

    // IDs that appear in the reordered view
    final viewIds = reorderedView.map((n) => n.id).toSet();

    // Notes outside the current view keep their relative order
    final nonViewNotes = allNotes
        .where((n) => !viewIds.contains(n.id))
        .toList();

    final fullOrdered = [...reorderedView, ...nonViewNotes];

    final repo = ref.read(notesRepositoryProvider);
    await repo.saveOrder(fullOrdered);
    await ref.read(notesSortByProvider.notifier).setSort('manual');
    await ref.read(notesProvider.notifier).refresh();
  }

  /// Searches notes
  void searchNotes(String query) {
    _notesNotifier.searchNotes(query);
  }

  /// Refreshes notes list
  void refresh() {
    _notesNotifier.refresh();
  }
}

/// Provider for the notes controller
final notesControllerProvider =
    NotifierProvider<NotesController, AsyncValue<void>>(NotesController.new);

/// Provider for search functionality
final notesSearchQueryProvider = stateProvider<String>('');
final selectedNoteTagProvider = stateProvider<String?>(null);

class NotesDrawerTagScopeNotifier extends Notifier<String> {
  @override
  String build() {
    return StorageService.getNotesDrawerTagScope();
  }

  Future<void> setScope(String scope) async {
    if (scope != 'all' && scope != 'folder') {
      return;
    }
    state = scope;
    await StorageService.setNotesDrawerTagScope(scope);
  }
}

/// Scope for tag overview shown in notes drawer: 'all' or 'folder'.
final notesDrawerTagScopeProvider =
    NotifierProvider<NotesDrawerTagScopeNotifier, String>(
      NotesDrawerTagScopeNotifier.new,
    );

List<Note> _scopeDrawerNotes({
  required List<Note> notes,
  required List<NoteFolder> folders,
  required String scope,
  required String? selectedFolderId,
}) {
  final vaultFolderIds = folders
      .where((folder) => folder.isVault)
      .map((folder) => folder.id)
      .toSet();

  var scopedNotes = notes.where((note) {
    return note.folderId == null || !vaultFolderIds.contains(note.folderId);
  }).toList();

  if (scope == 'folder') {
    if (selectedFolderId == 'UNFILED') {
      scopedNotes = scopedNotes.where((note) => note.folderId == null).toList();
    } else if (selectedFolderId != null) {
      scopedNotes = scopedNotes
          .where((note) => note.folderId == selectedFolderId)
          .toList();
    }
  }

  return scopedNotes;
}

List<String> _collectUniqueTags(Iterable<Note> notes) {
  final tagsMap = <String, String>{};
  for (final note in notes) {
    for (final rawTag in note.tags) {
      final cleaned = rawTag.trim();
      if (cleaned.isEmpty) continue;
      final key = cleaned.toLowerCase();
      tagsMap.putIfAbsent(key, () => cleaned);
    }
  }
  return tagsMap.values.toList();
}

List<String> orderTagsByRecentUsage({
  required List<String> tags,
  required List<String> recentTags,
}) {
  final canonicalByLower = <String, String>{};
  for (final tag in tags) {
    final cleaned = tag.trim();
    if (cleaned.isEmpty) continue;
    canonicalByLower.putIfAbsent(cleaned.toLowerCase(), () => cleaned);
  }

  final ordered = <String>[];
  final usedKeys = <String>{};

  for (final raw in recentTags) {
    final key = raw.trim().toLowerCase();
    if (key.isEmpty || usedKeys.contains(key)) continue;
    final canonical = canonicalByLower[key];
    if (canonical != null) {
      ordered.add(canonical);
      usedKeys.add(key);
    }
  }

  final remaining =
      canonicalByLower.entries
          .where((entry) => !usedKeys.contains(entry.key))
          .map((entry) => entry.value)
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return [...ordered, ...remaining];
}

List<String> buildDrawerTags({
  required List<Note> notes,
  required List<NoteFolder> folders,
  required String scope,
  required String? selectedFolderId,
  required List<String> recentTags,
}) {
  final scopedNotes = _scopeDrawerNotes(
    notes: notes,
    folders: folders,
    scope: scope,
    selectedFolderId: selectedFolderId,
  );

  final uniqueTags = _collectUniqueTags(scopedNotes);
  return orderTagsByRecentUsage(tags: uniqueTags, recentTags: recentTags);
}

/// Tags for drawer overview, optionally scoped to selected folder.
/// Vault tags are always excluded for privacy.
final drawerNoteTagsProvider = Provider<List<String>>((ref) {
  final scope = ref.watch(notesDrawerTagScopeProvider);
  final selectedFolderId = ref.watch(selectedNoteFolderProvider);
  final allNotesAsync = ref.watch(notesProvider);
  final foldersAsync = ref.watch(noteFoldersProvider);

  final allNotes = allNotesAsync.maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );
  final folders = foldersAsync.maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );
  if (allNotes == null || folders == null) {
    return const [];
  }

  final recentTags = StorageService.getRecentNoteTags();
  return buildDrawerTags(
    notes: allNotes,
    folders: folders,
    scope: scope,
    selectedFolderId: selectedFolderId,
    recentTags: recentTags,
  );
});

/// Available note tags in current folder scope (or all non-vault notes).
final availableNoteTagsProvider = Provider<List<String>>((ref) {
  final selectedFolderId = ref.watch(selectedNoteFolderProvider);
  final allNotesAsync = ref.watch(notesProvider);
  final foldersAsync = ref.watch(noteFoldersProvider);

  final allNotes = allNotesAsync.maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );
  final folders = foldersAsync.maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );
  if (allNotes == null || folders == null) {
    return const [];
  }

  var scopedNotes = allNotes;
  if (selectedFolderId != null) {
    if (selectedFolderId == 'UNFILED') {
      scopedNotes = scopedNotes.where((note) => note.folderId == null).toList();
    } else {
      scopedNotes = scopedNotes
          .where((note) => note.folderId == selectedFolderId)
          .toList();
    }
  } else {
    final vaultFolderIds = folders
        .where((folder) => folder.isVault)
        .map((folder) => folder.id)
        .toSet();
    scopedNotes = scopedNotes.where((note) {
      return note.folderId == null || !vaultFolderIds.contains(note.folderId);
    }).toList();
  }

  final tagsMap = <String, String>{};
  for (final note in scopedNotes) {
    for (final rawTag in note.tags) {
      final cleaned = rawTag.trim();
      if (cleaned.isEmpty) continue;
      final key = cleaned.toLowerCase();
      tagsMap.putIfAbsent(key, () => cleaned);
    }
  }

  final tags = tagsMap.values.toList();
  tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return tags;
});

class NotesSortNotifier extends Notifier<String> {
  @override
  String build() {
    _loadSavedSort();
    return 'date_modified';
  }

  Future<void> _loadSavedSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('notes_sort_by');
      if (saved != null) {
        state = saved;
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> setSort(String sort) async {
    state = sort;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notes_sort_by', sort);
    } catch (e) {
      // Ignore errors
    }
  }
}

final notesSortByProvider = NotifierProvider<NotesSortNotifier, String>(
  NotesSortNotifier.new,
);

/// Provider for notes view mode (grid or list)
final notesViewModeProvider = stateProvider<String>('grid');

/// Provider for filtered/searched notes
final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final searchQuery = ref.watch(notesSearchQueryProvider);
  final selectedFolderId = ref.watch(selectedNoteFolderProvider);
  final selectedTag = ref.watch(selectedNoteTagProvider);
  final allNotesAsync = ref.watch(notesProvider);
  final foldersAsync = ref.watch(noteFoldersProvider);
  final sortBy = ref.watch(notesSortByProvider);

  // If folders are still loading, show loading state
  if (foldersAsync.isLoading) {
    return const AsyncValue.loading();
  }

  return allNotesAsync.when(
    data: (allNotes) {
      var filtered = allNotes;

      // Filter by folder if one is selected
      if (selectedFolderId != null) {
        if (selectedFolderId == 'UNFILED') {
          // Show only notes that are not in any folder
          filtered = filtered.where((note) => note.folderId == null).toList();
        } else {
          // Show notes in the selected folder
          filtered = filtered
              .where((note) => note.folderId == selectedFolderId)
              .toList();
        }
      } else {
        // When viewing "All Notes", exclude notes from vault folders
        foldersAsync.whenData((folders) {
          final vaultFolderIds = folders
              .where((folder) => folder.isVault)
              .map((folder) => folder.id)
              .toSet();

          filtered = filtered.where((note) {
            // Exclude notes that belong to vault folders
            return note.folderId == null ||
                !vaultFolderIds.contains(note.folderId);
          }).toList();
        });
      }

      if (selectedTag != null) {
        filtered = filtered.where((note) {
          return note.tags.any(
            (tag) => tag.toLowerCase() == selectedTag.toLowerCase(),
          );
        }).toList();
      }

      // Filter by search query if provided with fuzzy matching
      if (searchQuery.isNotEmpty) {
        filtered = FuzzySearch.filter(
          items: filtered,
          query: searchQuery,
          getText: (note) =>
              '${note.title} ${note.content} ${note.tags.join(' ')}',
          minSimilarity: 0.6,
        );
      }

      filtered = List.of(filtered);

      // First sort by the selected criteria
      switch (sortBy) {
        case 'date_created':
          filtered.sort((a, b) {
            final aCreated =
                a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bCreated =
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bCreated.compareTo(aCreated);
          });
          break;
        case 'alphabetical':
          filtered.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
          break;
        case 'manual':
          break; // preserve storage insertion order
        case 'date_modified':
        default:
          filtered.sort((a, b) {
            final aUpdated =
                a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bUpdated =
                b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bUpdated.compareTo(aUpdated);
          });
          break;
      }

      // Then ensure pinned notes are always on top, maintaining the sort order within groups
      filtered.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return 0; // Keep existing sort order
      });

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
