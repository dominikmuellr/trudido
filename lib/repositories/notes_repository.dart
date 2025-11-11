import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../utils/encryption_helper.dart';
import '../repositories/note_folder_repository.dart';

/// Repository for managing note data persistence using Hive storage
class NotesRepository {
  final NoteFolderRepository _folderRepository;

  NotesRepository(this._folderRepository);

  /// Checks if a folder is a vault folder
  Future<bool> _isVaultFolder(String? folderId) async {
    if (folderId == null) return false;
    // Wait for note folders to be ready before checking
    await StorageService.waitNoteFoldersReady();
    final folder = _folderRepository.getNoteFolderById(folderId);
    final isVault = folder?.isVault ?? false;
    print(
      'Checking folder $folderId: folder=${folder?.name}, isVault=$isVault',
    );
    return isVault;
  }

  /// Encrypts note content if it belongs to a vault folder
  Future<Note> _encryptNoteIfNeeded(Note note) async {
    if (note.folderId != null && await _isVaultFolder(note.folderId)) {
      // Encrypt both title and content
      final encryptedTitle = await EncryptionHelper.encryptText(note.title);
      final encryptedContent = await EncryptionHelper.encryptText(note.content);
      return note.copyWith(title: encryptedTitle, content: encryptedContent);
    }
    return note;
  }

  /// Decrypts note content if it belongs to a vault folder
  Future<Note> _decryptNoteIfNeeded(Note note) async {
    if (note.folderId != null && await _isVaultFolder(note.folderId)) {
      try {
        print(
          'Attempting to decrypt note ${note.id} in vault folder ${note.folderId}',
        );
        // Decrypt both title and content
        final decryptedTitle = await EncryptionHelper.decryptText(note.title);
        final decryptedContent = await EncryptionHelper.decryptText(
          note.content,
        );
        print('Successfully decrypted note ${note.id}');
        return note.copyWith(title: decryptedTitle, content: decryptedContent);
      } catch (e) {
        // If decryption fails, return original (may show as encrypted)
        print('Failed to decrypt note ${note.id}: $e');
        return note;
      }
    }
    return note;
  }

  /// Gets all notes sorted by pinned first, then by most recently updated
  Future<List<Note>> getAllNotes() async {
    await StorageService.waitNotesReady();
    final notes = StorageService.getAllNotes();
    print('getAllNotes: Loading ${notes.length} notes from storage');

    // Decrypt vault notes
    final decryptedNotes = <Note>[];
    for (final note in notes) {
      decryptedNotes.add(await _decryptNoteIfNeeded(note));
    }
    print('getAllNotes: Decrypted ${decryptedNotes.length} notes');

    final sortedNotes = List<Note>.from(decryptedNotes); // Create mutable copy
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
  Future<Note?> getNoteById(String id) async {
    final note = StorageService.getNote(id);
    if (note == null) return null;
    return await _decryptNoteIfNeeded(note);
  }

  /// Creates a new note
  Future<Note> createNote({
    required String title,
    required String content,
    bool isPinned = false,
    String? folderId,
    String? todoTxtContent,
  }) async {
    final note = Note(
      title: title,
      content: content,
      isPinned: isPinned,
      folderId: folderId,
      todoTxtContent: todoTxtContent,
    );

    // Encrypt if vault folder
    final noteToSave = await _encryptNoteIfNeeded(note);
    await StorageService.saveNote(noteToSave);

    // Return the unencrypted version to the UI
    return note;
  }

  /// Updates an existing note
  Future<Note?> updateNote({
    required String id,
    String? title,
    String? content,
    bool? isPinned,
    String? folderId,
    String? todoTxtContent,
  }) async {
    final existingNote = StorageService.getNote(id);
    if (existingNote == null) return null;

    // Decrypt existing note first if it's in a vault
    final decryptedNote = await _decryptNoteIfNeeded(existingNote);

    final updatedNote = decryptedNote.copyWith(
      title: title ?? decryptedNote.title,
      content: content ?? decryptedNote.content,
      isPinned: isPinned ?? decryptedNote.isPinned,
      folderId: folderId ?? decryptedNote.folderId,
      todoTxtContent: todoTxtContent ?? decryptedNote.todoTxtContent,
      updatedAt: DateTime.now(),
    );

    // Encrypt if vault folder
    final noteToSave = await _encryptNoteIfNeeded(updatedNote);
    await StorageService.saveNote(noteToSave);

    // Return the unencrypted version to the UI
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

    // Decrypt all notes first
    final decryptedNotes = <Note>[];
    for (final note in allNotes) {
      decryptedNotes.add(await _decryptNoteIfNeeded(note));
    }

    final filteredNotes = decryptedNotes
        .where(
          (note) =>
              note.title.toLowerCase().contains(lowerQuery) ||
              note.content.toLowerCase().contains(lowerQuery),
        )
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
  return NotesRepository(NoteFolderRepository());
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
  }) async {
    final repository = ref.read(notesRepositoryProvider);
    final note = await repository.updateNote(
      id: id,
      title: title,
      content: content,
      isPinned: isPinned,
      folderId: folderId,
      todoTxtContent: todoTxtContent,
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
}
