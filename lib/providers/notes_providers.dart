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
import '../models/note.dart';
import '../repositories/notes_repository.dart';

const Object _providerSentinel = Object();

/// Provider for the list of all notes
/// Provider for the notes notifier
final notesProvider = AsyncNotifierProvider<NotesNotifier, List<Note>>(() {
  return NotesNotifier();
});

/// Notifier for managing notes state
class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final repository = ref.read(notesRepositoryProvider);
    return await repository.getAllNotes();
  }

  /// Refreshes the notes list
  Future<void> refresh() async {
    final repository = ref.read(notesRepositoryProvider);
    state = AsyncValue.data(await repository.getAllNotes());
  }

  /// Creates a new note
  Future<Note> createNote({
    required String title,
    required String content,
    String? folderId,
    String? todoTxtContent,
  }) async {
    final repository = ref.read(notesRepositoryProvider);
    final note = await repository.createNote(
      title: title,
      content: content,
      folderId: folderId,
      todoTxtContent: todoTxtContent,
    );
    await refresh();
    return note;
  }

  /// Updates a note
  Future<Note?> updateNote({
    required String id,
    String? title,
    String? content,
    bool? isPinned,
    String? folderId,
    String? todoTxtContent,
    double? lineHeightMultiplier,
    double? paragraphSpacing,
    bool? lastReadMode,
    Object? colorValue = _providerSentinel,
  }) async {
    final repository = ref.read(notesRepositoryProvider);
    final note = await repository.updateNote(
      id: id,
      title: title,
      content: content,
      isPinned: isPinned,
      folderId: folderId,
      todoTxtContent: todoTxtContent,
      lineHeightMultiplier: lineHeightMultiplier,
      paragraphSpacing: paragraphSpacing,
      lastReadMode: lastReadMode,
      colorValue: colorValue,
    );
    if (note != null) {
      await refresh();
    }
    return note;
  }

  /// Updates a note's folder assignment
  Future<Note?> updateNoteFolder(String noteId, String? folderId) async {
    return updateNote(id: noteId, folderId: folderId);
  }

  /// Toggles the pinned status of a note
  Future<Note?> togglePin(String id) async {
    final repository = ref.read(notesRepositoryProvider);
    final existingNote = await repository.getNoteById(id);
    if (existingNote == null) return null;

    final note = await repository.updateNote(
      id: id,
      isPinned: !existingNote.isPinned,
    );
    if (note != null) {
      await refresh();
    }
    return note;
  }

  /// Deletes a note
  Future<bool> deleteNote(String id) async {
    final repository = ref.read(notesRepositoryProvider);
    final success = await repository.deleteNote(id);
    if (success) {
      await refresh();
    }
    return success;
  }

  /// Searches notes
  Future<void> searchNotes(String query) async {
    final repository = ref.read(notesRepositoryProvider);
    state = AsyncValue.data(await repository.searchNotes(query));
  }

  /// Bulk deletes multiple notes by ID
  Future<void> bulkDelete(Iterable<String> ids) async {
    final repository = ref.read(notesRepositoryProvider);
    for (final id in ids) {
      await repository.deleteNote(id);
    }
    await refresh();
  }

  /// Sets the same card color on multiple notes
  Future<void> bulkSetColor(Iterable<String> ids, int? colorValue) async {
    final repository = ref.read(notesRepositoryProvider);
    for (final id in ids) {
      await repository.updateNote(
        id: id,
        colorValue: colorValue,
        preserveUpdatedAt: true,
      );
    }
    await refresh();
  }
}
