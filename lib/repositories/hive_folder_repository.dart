import 'package:hive/hive.dart';
import '../models/folder.dart';
import '../repositories/folder_repository.dart';
import '../services/storage_service.dart';

/// Concrete implementation of FolderRepository using Hive for local storage
class HiveFolderRepository implements FolderRepository {
  static const String _foldersBoxName = 'folders';
  Box<Folder>? _foldersBox;

  /// Initialize the repository with Hive boxes
  Future<void> init() async {
    _foldersBox = await Hive.openBox<Folder>(_foldersBoxName);
    // Create default folders if none exist
    await _createDefaultFoldersIfNeeded();
  }

  @override
  Future<List<Folder>> getAllFolders() async {
    if (_foldersBox == null) await init();
    return _foldersBox!.values.toList();
  }

  @override
  Future<Folder?> getFolderById(String id) async {
    if (_foldersBox == null) await init();
    return _foldersBox!.get(id);
  }

  @override
  Future<void> createFolder(Folder folder) async {
    if (_foldersBox == null) await init();
    await _foldersBox!.put(folder.id, folder);
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    if (_foldersBox == null) await init();
    final updatedFolder = folder.copyWith(updatedAt: DateTime.now());
    await _foldersBox!.put(folder.id, updatedFolder);
  }

  @override
  Future<void> deleteFolder(String id) async {
    if (_foldersBox == null) await init();
    // Ensure todos storage ready
    await StorageService.waitTodosReady();
    final todos = await StorageService.getAllTodosAsync();
    final affected = todos.where((t) => t.folderId == id).toList();
    if (affected.isNotEmpty) {
      final defaultFolder = await _getDefaultFolder();
      for (final todo in affected) {
        final updatedTodo = todo.copyWith(folderId: defaultFolder?.id);
        await StorageService.updateTodo(updatedTodo);
      }
    }
    await _foldersBox!.delete(id);
  }

  @override
  Future<List<Folder>> getFoldersSorted() async {
    final folders = await getAllFolders();
    // Deduplicate by name (case-insensitive) keeping earliest createdAt and marking others for removal.
    final seen = <String, Folder>{};
    final dups = <Folder>[];
    for (final f in folders) {
      final key = f.name.toLowerCase();
      if (!seen.containsKey(key)) {
        seen[key] = f;
      } else {
        // Keep the one that is default or earliest created
        final keep = _pickFolderToKeep(seen[key]!, f);
        final drop = keep == seen[key]! ? f : seen[key]!;
        seen[key] = keep;
        if (!dups.contains(drop)) dups.add(drop);
      }
    }
    if (dups.isNotEmpty) {
      for (final d in dups) {
        await _foldersBox!.delete(d.id);
      }
      folders.removeWhere((f) => dups.any((d) => d.id == f.id));
    }
    folders.sort((a, b) {
      // Default folders first, then by sort order, then by name
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;

      final sortOrderComparison = a.sortOrder.compareTo(b.sortOrder);
      if (sortOrderComparison != 0) return sortOrderComparison;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return folders;
  }

  @override
  Future<void> updateFolderOrder(List<String> folderIds) async {
    if (_foldersBox == null) await init();

    for (int i = 0; i < folderIds.length; i++) {
      final folder = await getFolderById(folderIds[i]);
      if (folder != null) {
        final updatedFolder = folder.copyWith(
          sortOrder: i,
          updatedAt: DateTime.now(),
        );
        await _foldersBox!.put(folder.id, updatedFolder);
      }
    }
  }

  @override
  Future<List<Folder>> getDefaultFolders() async {
    final folders = await getAllFolders();
    return folders.where((folder) => folder.isDefault).toList();
  }

  @override
  Future<bool> folderNameExists(String name, {String? excludeId}) async {
    final folders = await getAllFolders();
    return folders.any(
      (folder) =>
          folder.name.toLowerCase() == name.toLowerCase() &&
          folder.id != excludeId,
    );
  }

  @override
  Future<Map<String, int>> getFolderTaskCounts() async {
    await StorageService.waitTodosReady();
    final todos = await StorageService.getAllTodosAsync();
    final folderCounts = <String, int>{};
    final folders = await getAllFolders();
    for (final folder in folders) {
      folderCounts[folder.id] = 0;
    }
    for (final todo in todos) {
      final fid = todo.folderId;
      if (fid != null) folderCounts[fid] = (folderCounts[fid] ?? 0) + 1;
    }
    return folderCounts;
  }

  @override
  Future<List<Folder>> searchFolders(String query) async {
    final folders = await getAllFolders();
    final lowercaseQuery = query.toLowerCase();

    return folders.where((folder) {
      final nameMatch = folder.name.toLowerCase().contains(lowercaseQuery);
      final descriptionMatch =
          folder.description?.toLowerCase().contains(lowercaseQuery) ?? false;
      return nameMatch || descriptionMatch;
    }).toList();
  }

  /// Helper method to get todos in a specific folder
  // Removed direct todos box usage; rely on StorageService's lazy box.

  /// Helper method to get the default folder
  Future<Folder?> _getDefaultFolder() async {
    final defaultFolders = await getDefaultFolders();
    return defaultFolders.isNotEmpty ? defaultFolders.first : null;
  }

  /// Create default folders if none exist
  Future<void> _createDefaultFoldersIfNeeded() async {
    final existing = _foldersBox!.values.toList();
    final existingNames = existing.map((f) => f.name.toLowerCase()).toSet();
    Future<void> ensure(
      String name,
      String desc,
      int color,
      String icon,
      int order,
    ) async {
      if (existingNames.contains(name.toLowerCase())) return;
      // Recheck after potential race
      final latestNames = _foldersBox!.values
          .map((f) => f.name.toLowerCase())
          .toSet();
      if (latestNames.contains(name.toLowerCase())) return;
      await createFolder(
        Folder(
          name: name,
          description: desc,
          color: color,
          icon: icon,
          isDefault: true,
          sortOrder: order,
        ),
      );
    }

    await ensure(
      'Personal',
      'Personal tasks and reminders',
      0xFF2196F3,
      'person',
      0,
    );
    await ensure(
      'Work',
      'Work-related tasks and projects',
      0xFF4CAF50,
      'work',
      1,
    );
    await ensure(
      'Shopping',
      'Shopping lists and purchases',
      0xFFFF9800,
      'shopping_cart',
      2,
    );
  }

  Folder _pickFolderToKeep(Folder a, Folder b) {
    // Prefer default, then earlier createdAt, then lower id lexicographically
    if (a.isDefault != b.isDefault) return a.isDefault ? a : b;
    if (a.createdAt != b.createdAt)
      return a.createdAt.isBefore(b.createdAt) ? a : b;
    return a.id.compareTo(b.id) <= 0 ? a : b;
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _foldersBox?.close();
  }
}
