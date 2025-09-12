import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';

/// Controller for handling notes business logic
class NotesController extends StateNotifier<AsyncValue<void>> {
  final NotesNotifier _notesNotifier;

  NotesController(this._notesNotifier) : super(const AsyncValue.data(null));

  /// Creates a new note
  Future<Note?> createNote({
    required String title,
    required String content,
  }) async {
    // Validate input
    if (title.trim().isEmpty) {
      state = const AsyncValue.error('Title cannot be empty', StackTrace.empty);
      return null;
    }

    try {
      state = const AsyncValue.loading();
      final note = _notesNotifier.createNote(
        title: title.trim(),
        content: content,
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
      );
      state = const AsyncValue.data(null);
      return note;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
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
final notesControllerProvider = StateNotifierProvider<NotesController, AsyncValue<void>>((ref) {
  final notesNotifier = ref.watch(notesProvider.notifier);
  return NotesController(notesNotifier);
});

/// Provider for search functionality
final notesSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for filtered/searched notes
final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final searchQuery = ref.watch(notesSearchQueryProvider);
  final allNotesAsync = ref.watch(notesProvider);
  
  return allNotesAsync.when(
    data: (allNotes) {
      if (searchQuery.isEmpty) {
        return AsyncValue.data(allNotes);
      }
      
      final lowerQuery = searchQuery.toLowerCase();
      final filtered = allNotes.where((note) =>
        note.title.toLowerCase().contains(lowerQuery) ||
        note.content.toLowerCase().contains(lowerQuery)
      ).toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
