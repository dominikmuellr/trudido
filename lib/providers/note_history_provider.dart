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
import '../models/note_history.dart';
import '../services/storage_service.dart';

/// Provider for note history entries for a specific note (newest first).
final noteHistoryProvider =
    FutureProvider.family<List<NoteHistoryEntry>, String>((ref, noteId) async {
      return StorageService.getNoteHistoryForNote(noteId);
    });

/// Provider for all note history entries across all notes.
final allNoteHistoryProvider = FutureProvider<List<NoteHistoryEntry>>((
  ref,
) async {
  return StorageService.getAllNoteHistory();
});

/// Tracks whether we are currently previewing a past version for a given note.
/// The value is the entry ID being previewed, or null when at the live version.
class NoteHistoryNavigationNotifier extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => {};

  void setViewingEntry(String noteId, String? entryId) {
    state = {...state, noteId: entryId};
  }

  void resetToLive(String noteId) {
    state = {...state, noteId: null};
  }

  bool isViewingPast(String noteId) => state[noteId] != null;
}

final noteHistoryNavigationProvider =
    NotifierProvider<NoteHistoryNavigationNotifier, Map<String, String?>>(
      NoteHistoryNavigationNotifier.new,
    );

/// Whether we are currently previewing a past version for a note.
final isViewingPastProvider = Provider.family<bool, String>((ref, noteId) {
  final states = ref.watch(noteHistoryNavigationProvider);
  return states[noteId] != null;
});

/// True when there is at least one history entry to undo to.
final canUndoProvider = Provider.family<bool, String>((ref, noteId) {
  final historyAsync = ref.watch(noteHistoryProvider(noteId));
  return historyAsync.when(
    data: (entries) => entries.isNotEmpty,
    loading: () => false,
    error: (e, s) => false,
  );
});

/// True when we are currently viewing a past version (redo = return to live).
final canRedoProvider = Provider.family<bool, String>((ref, noteId) {
  return ref.watch(isViewingPastProvider(noteId));
});

/// The entry ID currently being previewed, or null when at the live version.
final currentHistoryPositionProvider = Provider.family<String?, String>((
  ref,
  noteId,
) {
  final states = ref.watch(noteHistoryNavigationProvider);
  return states[noteId];
});

/// Notifier for saving new history entries to persistent storage.
class NoteHistoryStackNotifier extends Notifier<void> {
  // Tracks the last saved contentAfter per note to deduplicate back-to-back
  // entries with identical content (e.g. from concurrent async save paths).
  final Map<String, String?> _lastSavedContentAfter = {};

  @override
  void build() {}

  /// Save a new history entry and refresh the history provider.
  Future<void> pushUndo(String noteId, NoteHistoryEntry entry) async {
    if (_lastSavedContentAfter[noteId] == entry.contentAfter) return;
    await StorageService.saveNoteHistoryEntry(entry);
    _lastSavedContentAfter[noteId] = entry.contentAfter;
    ref.invalidate(noteHistoryProvider(noteId));
  }

  /// Initialize from existing history (no-op — loaded lazily by providers).
  void initializeFromHistory(String noteId, List<NoteHistoryEntry> history) {
    ref.invalidate(noteHistoryProvider(noteId));
  }

  /// Whether currently at the live version (not browsing history).
  bool isAtLiveVersion(String noteId) {
    return !ref
        .read(noteHistoryNavigationProvider.notifier)
        .isViewingPast(noteId);
  }
}

final noteHistoryStackProvider =
    NotifierProvider<NoteHistoryStackNotifier, void>(
      NoteHistoryStackNotifier.new,
    );
