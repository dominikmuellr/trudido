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
