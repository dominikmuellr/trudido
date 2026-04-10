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
import '../models/folder.dart';
import '../repositories/folder_repository.dart';
import '../repositories/hive_folder_repository.dart';
import '../use_cases/folder_use_cases.dart';
import '../utils/date_search_parser.dart';
import '../utils/state_notifiers.dart';

// Repository provider
final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return HiveFolderRepository();
});

// Use case providers
final getFoldersUseCaseProvider = Provider<GetFoldersUseCase>((ref) {
  return GetFoldersUseCase(ref.read(folderRepositoryProvider));
});

final createFolderUseCaseProvider = Provider<CreateFolderUseCase>((ref) {
  return CreateFolderUseCase(ref.read(folderRepositoryProvider));
});

final updateFolderUseCaseProvider = Provider<UpdateFolderUseCase>((ref) {
  return UpdateFolderUseCase(ref.read(folderRepositoryProvider));
});

final deleteFolderUseCaseProvider = Provider<DeleteFolderUseCase>((ref) {
  return DeleteFolderUseCase(ref.read(folderRepositoryProvider));
});

final reorderFoldersUseCaseProvider = Provider<ReorderFoldersUseCase>((ref) {
  return ReorderFoldersUseCase(ref.read(folderRepositoryProvider));
});

final getFoldersWithTaskCountsUseCaseProvider =
    Provider<GetFoldersWithTaskCountsUseCase>((ref) {
      return GetFoldersWithTaskCountsUseCase(
        ref.read(folderRepositoryProvider),
      );
    });

final searchFoldersUseCaseProvider = Provider<SearchFoldersUseCase>((ref) {
  return SearchFoldersUseCase(ref.read(folderRepositoryProvider));
});

// State notifier for managing folder state
class FolderNotifier extends Notifier<AsyncValue<List<Folder>>> {
  GetFoldersUseCase get _getFoldersUseCase =>
      ref.read(getFoldersUseCaseProvider);
  CreateFolderUseCase get _createFolderUseCase =>
      ref.read(createFolderUseCaseProvider);
  UpdateFolderUseCase get _updateFolderUseCase =>
      ref.read(updateFolderUseCaseProvider);
  DeleteFolderUseCase get _deleteFolderUseCase =>
      ref.read(deleteFolderUseCaseProvider);
  ReorderFoldersUseCase get _reorderFoldersUseCase =>
      ref.read(reorderFoldersUseCaseProvider);

  @override
  AsyncValue<List<Folder>> build() {
    loadFolders();
    return const AsyncValue.loading();
  }

  /// Load all folders
  Future<void> loadFolders() async {
    state = const AsyncValue.loading();
    try {
      final folders = await _getFoldersUseCase();
      state = AsyncValue.data(folders);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Create a new folder
  Future<FolderCreationResult> createFolder({
    required String name,
    String? description,
    required int color,
    String? icon,
    bool isVault = false,
  }) async {
    final result = await _createFolderUseCase(
      CreateFolderParams(
        name: name,
        description: description,
        color: color,
        icon: icon,
        isVault: isVault,
      ),
    );

    if (result is FolderCreationSuccess) {
      // Reload folders to update the state
      await loadFolders();
    }

    return result;
  }

  /// Update a folder
  Future<FolderUpdateResult> updateFolder({
    required String folderId,
    required String name,
    String? description,
    required int color,
    String? icon,
    bool? isVault,
  }) async {
    final result = await _updateFolderUseCase(
      UpdateFolderParams(
        folderId: folderId,
        name: name,
        description: description,
        color: color,
        icon: icon,
        isVault: isVault,
      ),
    );

    if (result is FolderUpdateSuccess) {
      // Reload folders to update the state
      await loadFolders();
    }

    return result;
  }

  /// Delete a folder
  Future<FolderDeletionResult> deleteFolder(String folderId) async {
    final result = await _deleteFolderUseCase(folderId);

    if (result is FolderDeletionSuccess) {
      // Reload folders to update the state
      await loadFolders();
    }

    return result;
  }

  /// Reorder folders
  Future<void> reorderFolders(List<String> folderIds) async {
    await _reorderFoldersUseCase(folderIds);
    await loadFolders();
  }

  /// Get a specific folder by ID
  Folder? getFolderById(String id) {
    return state.whenData((folders) {
      try {
        return folders.firstWhere((folder) => folder.id == id);
      } catch (e) {
        return null;
      }
    }).value;
  }
}

// State notifier provider for folders
final folderNotifierProvider =
    NotifierProvider<FolderNotifier, AsyncValue<List<Folder>>>(
      FolderNotifier.new,
    );

// Provider for folders with task counts
final foldersWithTaskCountsProvider = FutureProvider<List<FolderWithTaskCount>>(
  (ref) {
    final useCase = ref.read(getFoldersWithTaskCountsUseCaseProvider);
    return useCase();
  },
);

// Provider for selected folder
final selectedFolderProvider = stateProvider<String?>(null);

// Provider for folder search query
final folderSearchQueryProvider = stateProvider<String>('');

// Provider for filtered folders based on search
final filteredFoldersProvider = Provider<AsyncValue<List<Folder>>>((ref) {
  final foldersAsync = ref.watch(folderNotifierProvider);
  final searchQuery = ref.watch(folderSearchQueryProvider);

  return foldersAsync.when(
    data: (folders) {
      if (searchQuery.trim().isEmpty) {
        return AsyncValue.data(folders);
      }

      final filteredFolders = FuzzySearch.filter(
        items: folders,
        query: searchQuery,
        getText: (folder) => '${folder.name} ${folder.description ?? ''}',
        minSimilarity: 0.6,
      );

      return AsyncValue.data(filteredFolders);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

// Provider for getting folder by ID
final folderByIdProvider = Provider.family<Folder?, String>((ref, folderId) {
  final foldersAsync = ref.watch(folderNotifierProvider);
  return foldersAsync.whenData((folders) {
    try {
      return folders.firstWhere((folder) => folder.id == folderId);
    } catch (e) {
      return null;
    }
  }).value;
});
