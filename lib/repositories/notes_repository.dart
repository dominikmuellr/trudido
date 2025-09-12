import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../services/storage_service.dart';

/// Repository for managing note data persistence using Hive storage
class NotesRepository {
  /// Gets all notes sorted by pinned first, then by most recently updated
  Future<List<Note>> getAllNotes() async {
    await StorageService.waitNotesReady();
    final notes = StorageService.getAllNotes();
    final sortedNotes = List<Note>.from(notes); // Create mutable copy
    sortedNotes.sort((a, b) {
      // First, sort by pinned status (pinned notes first)
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      // Then sort by updatedAt (most recent first)
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sortedNotes;
  }

  /// Gets a note by ID
  Note? getNoteById(String id) {
    return StorageService.getNote(id);
  }

  /// Creates a new note
  Future<Note> createNote({
    required String title,
    required String content,
    bool isPinned = false,
  }) async {
    final note = Note(
      title: title,
      content: content,
      isPinned: isPinned,
    );
    await StorageService.saveNote(note);
    return note;
  }

  /// Updates an existing note
  Future<Note?> updateNote({
    required String id,
    String? title,
    String? content,
    bool? isPinned,
  }) async {
    final existingNote = StorageService.getNote(id);
    if (existingNote == null) return null;

    final updatedNote = existingNote.copyWith(
      title: title ?? existingNote.title,
      content: content ?? existingNote.content,
      isPinned: isPinned ?? existingNote.isPinned,
      updatedAt: DateTime.now(),
    );

    await StorageService.saveNote(updatedNote);
    return updatedNote;
  }

  /// Deletes a note by ID
  Future<bool> deleteNote(String id) async {
    try {
      await StorageService.deleteNote(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Searches notes by title and content
  Future<List<Note>> searchNotes(String query) async {
    if (query.isEmpty) return await getAllNotes();
    
    await StorageService.waitNotesReady();
    final lowerQuery = query.toLowerCase();
    final allNotes = StorageService.getAllNotes();
    final filteredNotes = allNotes
        .where((note) =>
            note.title.toLowerCase().contains(lowerQuery) ||
            note.content.toLowerCase().contains(lowerQuery))
        .toList();
    final sortedNotes = List<Note>.from(filteredNotes); // Create mutable copy
    sortedNotes.sort((a, b) {
      // First, sort by pinned status (pinned notes first)
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      // Then sort by updatedAt (most recent first)
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sortedNotes;
  }
}

/// Provider for the notes repository
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository();
});

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
  Future<Note> createNote({required String title, required String content}) async {
    final repository = ref.read(notesRepositoryProvider);
    final note = await repository.createNote(title: title, content: content);
    await refresh();
    return note;
  }

  /// Updates a note
  Future<Note?> updateNote({
    required String id,
    String? title,
    String? content,
    bool? isPinned,
  }) async {
    final repository = ref.read(notesRepositoryProvider);
    final note = await repository.updateNote(id: id, title: title, content: content, isPinned: isPinned);
    if (note != null) {
      await refresh();
    }
    return note;
  }

  /// Toggles the pinned status of a note
  Future<Note?> togglePin(String id) async {
    final repository = ref.read(notesRepositoryProvider);
    final existingNote = repository.getNoteById(id);
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
}
