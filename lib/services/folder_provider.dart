import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../repositories/folder_repository.dart';
import '../repositories/hive_folder_repository.dart';
import '../use_cases/folder_use_cases.dart';

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
class FolderNotifier extends StateNotifier<AsyncValue<List<Folder>>> {
  final GetFoldersUseCase _getFoldersUseCase;
  final CreateFolderUseCase _createFolderUseCase;
  final UpdateFolderUseCase _updateFolderUseCase;
  final DeleteFolderUseCase _deleteFolderUseCase;
  final ReorderFoldersUseCase _reorderFoldersUseCase;

  FolderNotifier(
    this._getFoldersUseCase,
    this._createFolderUseCase,
    this._updateFolderUseCase,
    this._deleteFolderUseCase,
    this._reorderFoldersUseCase,
  ) : super(const AsyncValue.loading()) {
    loadFolders();
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
    StateNotifierProvider<FolderNotifier, AsyncValue<List<Folder>>>((ref) {
      return FolderNotifier(
        ref.read(getFoldersUseCaseProvider),
        ref.read(createFolderUseCaseProvider),
        ref.read(updateFolderUseCaseProvider),
        ref.read(deleteFolderUseCaseProvider),
        ref.read(reorderFoldersUseCaseProvider),
      );
    });

// Provider for folders with task counts
final foldersWithTaskCountsProvider = FutureProvider<List<FolderWithTaskCount>>(
  (ref) {
    final useCase = ref.read(getFoldersWithTaskCountsUseCaseProvider);
    return useCase();
  },
);

// Provider for selected folder
final selectedFolderProvider = StateProvider<String?>((ref) => null);

// Provider for folder search query
final folderSearchQueryProvider = StateProvider<String>((ref) => '');

// Provider for filtered folders based on search
final filteredFoldersProvider = Provider<AsyncValue<List<Folder>>>((ref) {
  final foldersAsync = ref.watch(folderNotifierProvider);
  final searchQuery = ref.watch(folderSearchQueryProvider);

  return foldersAsync.when(
    data: (folders) {
      if (searchQuery.trim().isEmpty) {
        return AsyncValue.data(folders);
      }

      final lowercaseQuery = searchQuery.toLowerCase();
      final filteredFolders = folders.where((folder) {
        final nameMatch = folder.name.toLowerCase().contains(lowercaseQuery);
        final descriptionMatch =
            folder.description?.toLowerCase().contains(lowercaseQuery) ?? false;
        return nameMatch || descriptionMatch;
      }).toList();

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
