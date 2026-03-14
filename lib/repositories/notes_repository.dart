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

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../models/note_history.dart';
import '../services/storage_service.dart';
import '../services/preferences_service.dart';
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
    debugPrint(
      'Checking folder $folderId: folder=${folder?.name}, isVault=$isVault',
    );
    return isVault;
  }

  /// Encrypts note content if it belongs to a vault folder
  Future<Note> _encryptNoteIfNeeded(Note note) async {
    if (note.folderId != null && await _isVaultFolder(note.folderId)) {
      try {
        debugPrint(
          'Encrypting note ${note.id} for vault folder ${note.folderId}',
        );
        // Encrypt title and content
        final encryptedTitle = await EncryptionHelper.encryptText(note.title);
        final encryptedContent = await EncryptionHelper.encryptText(
          note.content,
        );

        debugPrint('Successfully encrypted note ${note.id}');
        // Store encrypted values in the note fields (temporarily hijacking them)
        // Note: This relies on the fact that we're saving to Hive which stores dynamic types or strings
        // But since our model defines them as double, we can't store strings in double fields.
        // Wait, Hive stores what we give it, but the model enforces types.
        // Actually, for numeric fields, we usually don't encrypt them unless they are sensitive.
        // Line height and paragraph spacing are hardly sensitive data.
        // Let's ONLY encrypt title and content as before.
        // If user insists on encrypting everything, we'd need string fields for these.
        // Given the request "it should have the same defaults as a note in google keep",
        // and no specific request to encrypt layout settings, I will skip encrypting layout settings
        // to avoid type mismatch issues or needing schema changes.

        return note.copyWith(title: encryptedTitle, content: encryptedContent);
      } catch (e) {
        debugPrint('Failed to encrypt note ${note.id}: $e');
        rethrow; // Propagate error so caller knows encryption failed
      }
    }
    return note;
  }

  /// Decrypts note content if it belongs to a vault folder
  Future<Note> _decryptNoteIfNeeded(Note note) async {
    if (note.folderId != null && await _isVaultFolder(note.folderId)) {
      try {
        debugPrint(
          'Attempting to decrypt note ${note.id} in vault folder ${note.folderId}',
        );
        // Decrypt both title and content
        final decryptedTitle = await EncryptionHelper.decryptText(note.title);
        final decryptedContent = await EncryptionHelper.decryptText(
          note.content,
        );
        debugPrint('Successfully decrypted note ${note.id}');
        return note.copyWith(title: decryptedTitle, content: decryptedContent);
      } catch (e) {
        // If decryption fails, return original (may show as encrypted)
        debugPrint('Failed to decrypt note ${note.id}: $e');
        return note;
      }
    }
    return note;
  }

  /// Gets all notes sorted by pinned first, then by most recently updated
  Future<List<Note>> getAllNotes() async {
    await StorageService.waitNotesReady();
    final notes = StorageService.getAllNotes();
    debugPrint('getAllNotes: Loading ${notes.length} notes from storage');

    // Decrypt vault notes
    final decryptedNotes = <Note>[];
    for (final note in notes) {
      decryptedNotes.add(await _decryptNoteIfNeeded(note));
    }
    debugPrint('getAllNotes: Decrypted ${decryptedNotes.length} notes');

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
    double? lineHeightMultiplier,
    double? paragraphSpacing,
    bool? lastReadMode,
  }) async {
    final existingNote = StorageService.getNote(id);
    if (existingNote == null) return null;

    // Decrypt existing note first if it's in a vault
    final decryptedNote = await _decryptNoteIfNeeded(existingNote);

    // Record history if content changed
    final newContent = content ?? decryptedNote.content;
    if (newContent != decryptedNote.content) {
      final historyEntry = NoteHistoryEntry(
        noteId: id,
        contentBefore: decryptedNote.content,
        contentAfter: newContent,
      );
      await StorageService.saveNoteHistoryEntry(historyEntry);
    }

    final updatedNote = decryptedNote.copyWith(
      title: title ?? decryptedNote.title,
      content: content ?? decryptedNote.content,
      isPinned: isPinned ?? decryptedNote.isPinned,
      folderId: folderId ?? decryptedNote.folderId,
      todoTxtContent: todoTxtContent ?? decryptedNote.todoTxtContent,
      lineHeightMultiplier:
          lineHeightMultiplier ?? decryptedNote.lineHeightMultiplier,
      paragraphSpacing: paragraphSpacing ?? decryptedNote.paragraphSpacing,
      lastReadMode: lastReadMode ?? decryptedNote.lastReadMode,
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
      if (PreferencesService().snapshot.enableBin) {
        await StorageService.deleteNote(id);
      } else {
        await StorageService.permanentlyDeleteNote(id);
      }
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

  Future<List<Note>> getDeletedNotes() async {
    await StorageService.waitNotesReady();
    // Get raw deleted notes (encrypted)
    final notes = StorageService.getDeletedNotes();
    // We do NOT decrypt them here for the bin list, or we decrypt them but mark them?
    // For the bin, we might want to see titles if possible, but for vault notes we must be careful.
    // Let's return them as is. The UI will handle masking vault notes.
    return notes;
  }

  Future<void> restoreNote(String id) async {
    await StorageService.restoreNote(id);
  }

  Future<void> permanentlyDeleteNote(String id) async {
    await StorageService.permanentlyDeleteNote(id);
  }

  Future<void> emptyBin(bool onlyVault) async {
    final deleted = StorageService.getDeletedNotes();
    for (final note in deleted) {
      final isVault = await _isVaultFolder(note.folderId);
      if (onlyVault) {
        if (isVault) await StorageService.permanentlyDeleteNote(note.id);
      } else {
        if (!isVault) await StorageService.permanentlyDeleteNote(note.id);
      }
    }
  }
}

/// Provider for the notes repository
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(NoteFolderRepository());
});
