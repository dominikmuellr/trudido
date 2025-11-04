import '../models/folder.dart';
import '../repositories/folder_repository.dart';

/// Use case for getting all folders
class GetFoldersUseCase {
  final FolderRepository _repository;

  GetFoldersUseCase(this._repository);

  Future<List<Folder>> call() async {
    return await _repository.getFoldersSorted();
  }
}

/// Use case for creating a new folder
class CreateFolderUseCase {
  final FolderRepository _repository;

  CreateFolderUseCase(this._repository);

  Future<FolderCreationResult> call(CreateFolderParams params) async {
    // Validate folder name
    if (params.name.trim().isEmpty) {
      return FolderCreationResult.failure('Folder name cannot be empty');
    }

    if (params.name.trim().length > 50) {
      return FolderCreationResult.failure(
        'Folder name cannot exceed 50 characters',
      );
    }

    // Check if name already exists
    final nameExists = await _repository.folderNameExists(params.name.trim());
    if (nameExists) {
      return FolderCreationResult.failure(
        'A folder with this name already exists',
      );
    }

    final folder = Folder(
      name: params.name.trim(),
      description: params.description?.trim(),
      color: params.color,
      icon: params.icon,
      isVault: params.isVault,
    );

    try {
      await _repository.createFolder(folder);
      return FolderCreationResult.success(folder);
    } catch (e) {
      return FolderCreationResult.failure(
        'Failed to create folder: ${e.toString()}',
      );
    }
  }
}

/// Use case for updating a folder
class UpdateFolderUseCase {
  final FolderRepository _repository;

  UpdateFolderUseCase(this._repository);

  Future<FolderUpdateResult> call(UpdateFolderParams params) async {
    // Validate folder name
    if (params.name.trim().isEmpty) {
      return FolderUpdateResult.failure('Folder name cannot be empty');
    }

    if (params.name.trim().length > 50) {
      return FolderUpdateResult.failure(
        'Folder name cannot exceed 50 characters',
      );
    }

    // Check if name already exists (excluding current folder)
    final nameExists = await _repository.folderNameExists(
      params.name.trim(),
      excludeId: params.folderId,
    );
    if (nameExists) {
      return FolderUpdateResult.failure(
        'A folder with this name already exists',
      );
    }

    // Get current folder
    final existingFolder = await _repository.getFolderById(params.folderId);
    if (existingFolder == null) {
      return FolderUpdateResult.failure('Folder not found');
    }

    final updatedFolder = existingFolder.copyWith(
      name: params.name.trim(),
      description: params.description?.trim(),
      color: params.color,
      icon: params.icon,
      isVault: params.isVault,
    );

    try {
      await _repository.updateFolder(updatedFolder);
      return FolderUpdateResult.success(updatedFolder);
    } catch (e) {
      return FolderUpdateResult.failure(
        'Failed to update folder: ${e.toString()}',
      );
    }
  }
}

/// Use case for deleting a folder
class DeleteFolderUseCase {
  final FolderRepository _repository;

  DeleteFolderUseCase(this._repository);

  Future<FolderDeletionResult> call(String folderId) async {
    try {
      final folder = await _repository.getFolderById(folderId);
      if (folder == null) {
        return FolderDeletionResult.failure('Folder not found');
      }

      await _repository.deleteFolder(folderId);
      return FolderDeletionResult.success();
    } catch (e) {
      return FolderDeletionResult.failure(
        'Failed to delete folder: ${e.toString()}',
      );
    }
  }
}

/// Use case for reordering folders
class ReorderFoldersUseCase {
  final FolderRepository _repository;

  ReorderFoldersUseCase(this._repository);

  Future<void> call(List<String> folderIds) async {
    await _repository.updateFolderOrder(folderIds);
  }
}

/// Use case for getting folder with task counts
class GetFoldersWithTaskCountsUseCase {
  final FolderRepository _repository;

  GetFoldersWithTaskCountsUseCase(this._repository);

  Future<List<FolderWithTaskCount>> call() async {
    final folders = await _repository.getFoldersSorted();
    final taskCounts = await _repository.getFolderTaskCounts();

    return folders.map((folder) {
      final taskCount = taskCounts[folder.id] ?? 0;
      return FolderWithTaskCount(folder: folder, taskCount: taskCount);
    }).toList();
  }
}

/// Use case for searching folders
class SearchFoldersUseCase {
  final FolderRepository _repository;

  SearchFoldersUseCase(this._repository);

  Future<List<Folder>> call(String query) async {
    if (query.trim().isEmpty) {
      return await _repository.getFoldersSorted();
    }
    return await _repository.searchFolders(query.trim());
  }
}

// Data classes for parameters and results

class CreateFolderParams {
  final String name;
  final String? description;
  final int color;
  final String? icon;
  final bool isVault;

  CreateFolderParams({
    required this.name,
    this.description,
    required this.color,
    this.icon,
    this.isVault = false,
  });
}

class UpdateFolderParams {
  final String folderId;
  final String name;
  final String? description;
  final int color;
  final String? icon;
  final bool? isVault;

  UpdateFolderParams({
    required this.folderId,
    required this.name,
    this.description,
    required this.color,
    this.icon,
    this.isVault,
  });
}

class FolderWithTaskCount {
  final Folder folder;
  final int taskCount;

  FolderWithTaskCount({required this.folder, required this.taskCount});
}

// Result classes

abstract class FolderCreationResult {
  static FolderCreationResult success(Folder folder) =>
      FolderCreationSuccess(folder);
  static FolderCreationResult failure(String message) =>
      FolderCreationFailure(message);
}

class FolderCreationSuccess extends FolderCreationResult {
  final Folder folder;
  FolderCreationSuccess(this.folder);
}

class FolderCreationFailure extends FolderCreationResult {
  final String message;
  FolderCreationFailure(this.message);
}

abstract class FolderUpdateResult {
  static FolderUpdateResult success(Folder folder) =>
      FolderUpdateSuccess(folder);
  static FolderUpdateResult failure(String message) =>
      FolderUpdateFailure(message);
}

class FolderUpdateSuccess extends FolderUpdateResult {
  final Folder folder;
  FolderUpdateSuccess(this.folder);
}

class FolderUpdateFailure extends FolderUpdateResult {
  final String message;
  FolderUpdateFailure(this.message);
}

abstract class FolderDeletionResult {
  static FolderDeletionResult success() => FolderDeletionSuccess();
  static FolderDeletionResult failure(String message) =>
      FolderDeletionFailure(message);
}

class FolderDeletionSuccess extends FolderDeletionResult {}

class FolderDeletionFailure extends FolderDeletionResult {
  final String message;
  FolderDeletionFailure(this.message);
}
