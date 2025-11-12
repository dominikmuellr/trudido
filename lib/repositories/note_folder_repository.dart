import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_folder.dart';
import '../services/storage_service.dart';

/// Repository for managing note folder data
class NoteFolderRepository {
  /// Gets all note folders sorted by sort order
  Future<List<NoteFolder>> getAllNoteFolders() async {
    await StorageService.waitNoteFoldersReady();
    final folders = StorageService.getAllNoteFolders();
    final sortedFolders = List<NoteFolder>.from(folders);
    sortedFolders.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sortedFolders;
  }

  /// Gets a note folder by ID
  NoteFolder? getNoteFolderById(String id) {
    return StorageService.getNoteFolder(id);
  }

  /// Creates a new note folder
  Future<NoteFolder> createNoteFolder({
    required String name,
    String? description,
    bool isVault = false,
    bool hasPassword = false,
    bool useBiometric = true,
    String noteFormat = 'markdown',
  }) async {
    final folder = NoteFolder(
      name: name,
      description: description,
      isVault: isVault,
      hasPassword: hasPassword,
      useBiometric: useBiometric,
      noteFormat: noteFormat,
    );
    await StorageService.saveNoteFolder(folder);
    return folder;
  }

  /// Updates an existing note folder
  Future<NoteFolder?> updateNoteFolder(NoteFolder folder) async {
    final existingFolder = StorageService.getNoteFolder(folder.id);
    if (existingFolder == null) return null;

    final updatedFolder = folder.copyWith(updatedAt: DateTime.now());
    await StorageService.saveNoteFolder(updatedFolder);
    return updatedFolder;
  }

  /// Deletes a note folder by ID
  Future<bool> deleteNoteFolder(String id) async {
    try {
      await StorageService.deleteNoteFolder(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Checks if a folder name already exists
  Future<bool> folderNameExists(String name, {String? excludeId}) async {
    final folders = await getAllNoteFolders();
    return folders.any(
      (f) =>
          f.name.toLowerCase() == name.toLowerCase() &&
          (excludeId == null || f.id != excludeId),
    );
  }
}

/// Provider for the note folder repository
final noteFolderRepositoryProvider = Provider<NoteFolderRepository>((ref) {
  return NoteFolderRepository();
});

/// Provider for note folders list
final noteFoldersProvider =
    AsyncNotifierProvider<NoteFoldersNotifier, List<NoteFolder>>(() {
      return NoteFoldersNotifier();
    });

/// Notifier for managing note folders state
class NoteFoldersNotifier extends AsyncNotifier<List<NoteFolder>> {
  @override
  Future<List<NoteFolder>> build() async {
    final repository = ref.read(noteFolderRepositoryProvider);
    return await repository.getAllNoteFolders();
  }

  /// Refreshes the folders list
  Future<void> refresh() async {
    final repository = ref.read(noteFolderRepositoryProvider);
    state = AsyncValue.data(await repository.getAllNoteFolders());
  }

  /// Creates a new folder
  Future<NoteFolder?> createFolder({
    required String name,
    String? description,
    bool isVault = false,
    bool hasPassword = false,
    bool useBiometric = true,
    String noteFormat = 'markdown',
  }) async {
    final repository = ref.read(noteFolderRepositoryProvider);

    // Validate name
    if (name.trim().isEmpty) {
      return null;
    }

    // Check for duplicate names
    final exists = await repository.folderNameExists(name.trim());
    if (exists) {
      return null;
    }

    final folder = await repository.createNoteFolder(
      name: name.trim(),
      description: description?.trim(),
      isVault: isVault,
      hasPassword: hasPassword,
      useBiometric: useBiometric,
      noteFormat: noteFormat,
    );

    await refresh();
    return folder;
  }

  /// Updates a folder
  Future<NoteFolder?> updateFolder(NoteFolder folder) async {
    final repository = ref.read(noteFolderRepositoryProvider);

    // Check for duplicate names
    final exists = await repository.folderNameExists(
      folder.name,
      excludeId: folder.id,
    );
    if (exists) {
      return null;
    }

    final updated = await repository.updateNoteFolder(folder);
    if (updated != null) {
      await refresh();
    }
    return updated;
  }

  /// Deletes a folder
  Future<bool> deleteFolder(String id) async {
    final repository = ref.read(noteFolderRepositoryProvider);
    final success = await repository.deleteNoteFolder(id);
    if (success) {
      await refresh();
    }
    return success;
  }
}
