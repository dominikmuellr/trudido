import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/folder_provider.dart';
import '../widgets/folder_item.dart';
import '../widgets/create_folder_dialog.dart';
import '../widgets/edit_folder_dialog.dart';
import '../use_cases/folder_use_cases.dart';

class FolderManagementScreen extends ConsumerStatefulWidget {
  const FolderManagementScreen({super.key});

  @override
  ConsumerState<FolderManagementScreen> createState() =>
      _FolderManagementScreenState();
}

class _FolderManagementScreenState
    extends ConsumerState<FolderManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(filteredFoldersProvider);
    final foldersWithCounts = ref.watch(foldersWithTaskCountsProvider);
    final searchQuery = ref.watch(folderSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Folders'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showCreateFolderDialog(context),
            tooltip: 'Create Folder',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search folders...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(folderSearchQueryProvider.notifier).state =
                              '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) {
                ref.read(folderSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Folders list
          Expanded(
            child: foldersAsync.when(
              data: (folders) {
                if (folders.isEmpty) {
                  return _buildEmptyState(context);
                }

                return foldersWithCounts.when(
                  data: (foldersWithTaskCounts) {
                    // Create a map for quick lookup of task counts
                    final taskCountMap = <String, int>{};
                    for (final folderWithCount in foldersWithTaskCounts) {
                      taskCountMap[folderWithCount.folder.id] =
                          folderWithCount.taskCount;
                    }

                    return ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: folders.length,
                      onReorder: (oldIndex, newIndex) {
                        _reorderFolders(folders, oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        final taskCount = taskCountMap[folder.id] ?? 0;

                        return FolderItem(
                          key: ValueKey(folder.id),
                          folder: folder,
                          taskCount: taskCount,
                          onTap: () => _selectFolder(folder.id),
                          onEdit: () => _showEditFolderDialog(context, folder),
                          onDelete: folder.isDefault
                              ? null
                              : () => _deleteFolder(folder.id),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      Center(child: Text('Error loading task counts: $error')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading folders',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(folderNotifierProvider.notifier)
                          .loadFolders(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final searchQuery = ref.watch(folderSearchQueryProvider);

    if (searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'No folders found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No folders yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first folder to organize your tasks',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateFolderDialog(context),
            icon: Icon(Icons.add),
            label: const Text('Create Folder'),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );
  }

  void _showEditFolderDialog(BuildContext context, folder) {
    showDialog(
      context: context,
      builder: (context) => EditFolderDialog(folder: folder),
    );
  }

  void _reorderFolders(List folders, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Create new order based on the reordered list
    final reorderedFolders = List.from(folders);
    final item = reorderedFolders.removeAt(oldIndex);
    reorderedFolders.insert(newIndex, item);

    // Extract folder IDs in new order
    final folderIds = reorderedFolders.map((f) => f.id as String).toList();

    // Update the order
    ref.read(folderNotifierProvider.notifier).reorderFolders(folderIds);
  }

  void _selectFolder(String folderId) {
    ref.read(selectedFolderProvider.notifier).state = folderId;
    Navigator.pop(context);
  }

  void _deleteFolder(String folderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: const Text(
          'Are you sure you want to delete this folder? '
          'Tasks in this folder will be moved to the default folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ref
                  .read(folderNotifierProvider.notifier)
                  .deleteFolder(folderId);

              if (result is FolderDeletionFailure && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
