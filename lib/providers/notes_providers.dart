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
import 'dart:ui' show Offset;
import '../models/note.dart';
import '../repositories/notes_repository.dart';
import '../controllers/notes_controller.dart';
import '../services/storage_service.dart';
import '../utils/mention_parser.dart';

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
    double? lineHeightMultiplier,
    double? paragraphSpacing,
  }) async {
    final repository = ref.read(notesRepositoryProvider);
    final note = await repository.createNote(
      title: title,
      content: content,
      folderId: folderId,
      todoTxtContent: todoTxtContent,
      lineHeightMultiplier: lineHeightMultiplier,
      paragraphSpacing: paragraphSpacing,
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

  /// Sets the pinned status on multiple notes
  Future<void> bulkSetPin(Iterable<String> ids, bool pinned) async {
    final repository = ref.read(notesRepositoryProvider);
    for (final id in ids) {
      await repository.updateNote(
        id: id,
        isPinned: pinned,
        preserveUpdatedAt: true,
      );
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

// ============================================================================
// Spatial Canvas Positions
// ============================================================================

/// Manages Spatial Canvas positions per folder.
///
/// Automatically reloads when the selected folder changes.
/// Positions are persisted in SharedPreferences as JSON.
class FreeformPositionsNotifier extends Notifier<Map<String, Offset>> {
  String get _folderKey => ref.read(selectedNoteFolderProvider) ?? 'ALL';

  @override
  Map<String, Offset> build() {
    // Re-read when folder changes
    ref.watch(selectedNoteFolderProvider);
    return _load();
  }

  Map<String, Offset> _load() {
    final raw = StorageService.loadFreeformPositions(_folderKey);
    return raw.map((k, v) => MapEntry(k, Offset(v[0], v[1])));
  }

  /// Update a single note's position and persist.
  Future<void> updatePosition(String noteId, Offset pos) async {
    state = {...state, noteId: pos};
    await _save();
  }

  /// Batch-set positions for multiple notes and persist.
  Future<void> setPositions(Map<String, Offset> positions) async {
    state = {...state, ...positions};
    await _save();
  }

  /// Ensure all notes have a position; auto-place those that don't.
  /// Starts placing at [origin] in rows of [columns], with given spacing.
  Future<void> ensurePositions(
    List<String> noteIds, {
    Offset origin = const Offset(800, 400),
    int columns = 3,
    double colSpacing = 220,
    double rowSpacing = 280,
  }) async {
    final missing = noteIds.where((id) => !state.containsKey(id)).toList();
    if (missing.isEmpty) return;

    final newPositions = <String, Offset>{};
    for (var i = 0; i < missing.length; i++) {
      final col = i % columns;
      final row = i ~/ columns;
      newPositions[missing[i]] = Offset(
        origin.dx + col * colSpacing,
        origin.dy + row * rowSpacing,
      );
    }
    await setPositions(newPositions);
  }

  Future<void> _save() async {
    final raw = state.map((k, v) => MapEntry(k, [v.dx, v.dy]));
    await StorageService.saveFreeformPositions(_folderKey, raw);
  }
}

final noteFreeformPositionsProvider =
    NotifierProvider<FreeformPositionsNotifier, Map<String, Offset>>(
      FreeformPositionsNotifier.new,
    );

// ============================================================================
// Freeform Note Link Graph
// ============================================================================

/// Maps each note ID to the set of note IDs it @mentions.
/// Handles both markdown format `@[Title](note:uuid)` and Quill JSON
/// format `"mention:note:uuid"`. Only includes IDs present in the current
/// filtered note list so we never draw lines to invisible notes.
final noteFreeformLinksProvider = Provider<Map<String, Set<String>>>((ref) {
  final notesAsync = ref.watch(filteredNotesProvider);
  return notesAsync.maybeWhen(
    data: (notes) {
      final noteIdSet = notes.map((n) => n.id).toSet();
      final links = <String, Set<String>>{};
      for (final note in notes) {
        // Extract from markdown @[Title](note:uuid) format
        final mdIds = MentionParser.extractNoteIds(note.content);
        // Extract from Quill JSON "mention:note:uuid" format
        final quillIds = _extractQuillMentionNoteIds(note.content);
        final allIds = {...mdIds, ...quillIds}.intersection(noteIdSet);
        // Exclude self-references
        allIds.remove(note.id);
        if (allIds.isNotEmpty) links[note.id] = allIds;
      }
      return links;
    },
    orElse: () => {},
  );
});

/// Extracts note IDs from Quill JSON content where mentions are stored as
/// `"link":"mention:note:uuid"` attributes.
final RegExp _quillMentionNotePattern = RegExp(
  r'mention:note:([a-zA-Z0-9\-]+)',
);

Set<String> _extractQuillMentionNoteIds(String content) {
  final ids = <String>{};
  for (final match in _quillMentionNotePattern.allMatches(content)) {
    ids.add(match.group(1)!);
  }
  return ids;
}
