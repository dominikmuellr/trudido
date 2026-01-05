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
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';
import '../repositories/note_folder_repository.dart';

/// Provider for selected folder filter (null = all notes)
final selectedNoteFolderProvider = StateProvider<String?>((ref) => null);

/// Provider for tracking the last accessed vault folder ID
final lastAccessedVaultProvider = StateProvider<String?>((ref) => null);

/// Controller for handling notes business logic
class NotesController extends StateNotifier<AsyncValue<void>> {
  final NotesNotifier _notesNotifier;

  NotesController(this._notesNotifier) : super(const AsyncValue.data(null));

  /// Creates a new note
  Future<Note?> createNote({
    required String title,
    required String content,
    String? folderId,
    String? todoTxtContent,
  }) async {
    // Validate input
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
  }) async {
    // Validate input
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
    StateNotifierProvider<NotesController, AsyncValue<void>>((ref) {
      final notesNotifier = ref.watch(notesProvider.notifier);
      return NotesController(notesNotifier);
    });

/// Provider for search functionality
final notesSearchQueryProvider = StateProvider<String>((ref) => '');

class NotesSortNotifier extends StateNotifier<String> {
  NotesSortNotifier() : super('date_modified') {
    _loadSavedSort();
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

final notesSortByProvider = StateNotifierProvider<NotesSortNotifier, String>(
  (ref) => NotesSortNotifier(),
);

/// Provider for filtered/searched notes
final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final searchQuery = ref.watch(notesSearchQueryProvider);
  final selectedFolderId = ref.watch(selectedNoteFolderProvider);
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
        filtered = filtered
            .where((note) => note.folderId == selectedFolderId)
            .toList();
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

      // Filter by search query if provided
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered
            .where(
              (note) =>
                  note.title.toLowerCase().contains(lowerQuery) ||
                  note.content.toLowerCase().contains(lowerQuery),
            )
            .toList();
      }

      // Apply sorting
      // Create a mutable copy for sorting
      filtered = List.of(filtered);

      // First sort by the selected criteria
      switch (sortBy) {
        case 'date_created':
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'alphabetical':
          filtered.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
          break;
        case 'date_modified':
        default:
          filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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
