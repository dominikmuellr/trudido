import '../models/folder.dart';

/// Abstract repository interface for folder operations
/// This defines the contract that concrete implementations must follow
abstract class FolderRepository {
  /// Get all folders
  Future<List<Folder>> getAllFolders();

  /// Get folder by ID
  Future<Folder?> getFolderById(String id);

  /// Create a new folder
  Future<void> createFolder(Folder folder);

  /// Update an existing folder
  Future<void> updateFolder(Folder folder);

  /// Delete a folder by ID
  Future<void> deleteFolder(String id);

  /// Get folders sorted by custom order
  Future<List<Folder>> getFoldersSorted();

  /// Update folder sort order
  Future<void> updateFolderOrder(List<String> folderIds);

  /// Get default folders
  Future<List<Folder>> getDefaultFolders();

  /// Check if folder name already exists
  Future<bool> folderNameExists(String name, {String? excludeId});

  /// Get folder with task count
  Future<Map<String, int>> getFolderTaskCounts();

  /// Search folders by name
  Future<List<Folder>> searchFolders(String query);
}
